{-# LANGUAGE BangPatterns               #-}
{-# LANGUAGE CPP                        #-}
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveFoldable             #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveTraversable          #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TemplateHaskell            #-}

-- | The treeless syntax is intended to be used as input for the compiler backends.
-- It is more low-level than Internal syntax and is not used for type checking.
--
-- Some of the features of treeless syntax are:
-- - case expressions instead of case trees
-- - no instantiated datatypes / constructors
module Agda.Syntax.Treeless
    ( module Agda.Syntax.Abstract.Name
    , module Agda.Syntax.Treeless
    ) where

import Prelude hiding (foldr, mapM, null)

import Data.Map (Map)

-- base-4.7 defines the Num instance for Sum
#if !(MIN_VERSION_base(4,7,0))
import Data.Orphans             ()
#endif

import Data.Typeable (Typeable)

import Agda.Syntax.Position
import Agda.Syntax.Literal
import Agda.Syntax.Abstract.Name


type Args = [TTerm]

data TModule
  = TModule
  { mName :: ModuleName
  , mDataRec :: Map QName DataRecDef
  -- ^ Data and record types
  , mFuns :: Map QName FunDef
  }
  deriving (Typeable, Show)

data TType = TType { unEl :: TTerm }
  deriving (Typeable, Show, Eq, Ord)

data Def a
  = Def
    { name :: QName
    , ty :: TType
    , theDef :: a
    }
  deriving (Typeable, Show)

type DataRecDef = Def DataRecDef'
data DataRecDef'
  = Record
    { drdCon :: ConDef
    }
  | Datatype
    { drdCons :: [ConDef]
    }
  deriving (Typeable, Show)

type ConDef = Def ConDef'
data ConDef'
  = Con
    { cdName :: QName
    }
  deriving (Typeable, Show)

type FunDef = Def FunDef'
data FunDef'
  = Fun
    { fdBody :: TTerm
    }
  | Axiom
  | Primitive
    { fdPrimName :: String
    }
  | ForeignImport
  deriving (Typeable, Show)


-- this currently assumes that TApp is translated in a lazy/cbn fashion.
-- The AST should also support strict translation.
--
-- All local variables are using de Bruijn indices.
data TTerm = TVar Int
           | TPrim String
           | TDef QName
           | TApp TTerm Args
           | TLam TTerm
           | TLit Literal
           | TPlus Integer TTerm
           | TCon QName
           | TLet TTerm TTerm
           -- ^ introduces a new local binding. The bound term
           -- MUST only be evaluated if it is used inside the body.
           -- Sharing may happen, but is optional.
           -- It is also perfectly valid to just inline the bound term in the body.
           | TCase Int CaseType TTerm [TAlt]
           -- ^ Case scrutinee (always variable), case type, default value, alternatives
           | TPi TType TType
           -- ^ TODO: get rid of this?
           | TUnit -- used for levels right now
           | TSort
           | TErased
           | TError TError
           -- ^ A runtime error, something bad has happened.
  deriving (Typeable, Show, Eq, Ord)

mkTApp :: TTerm -> Args -> TTerm
mkTApp x [] = x
mkTApp x as = TApp x as

-- | Introduces a new binding
mkLet :: TTerm -> TTerm -> TTerm
mkLet x body = TLet x body

tInt :: Integer -> TTerm
tInt = TLit . LitInt noRange

data CaseType
  = CTData QName -- case on datatype
  | CTChar
  | CTString
  | CTQName
  deriving (Typeable, Show, Eq, Ord)

data TAlt
  = TACon    { aCon  :: QName, aArity :: Int, aBody :: TTerm }
  -- ^ Matches on the given constructor. If the match succeeds,
  -- the pattern variables are prepended to the current environment
  -- (pushes all existing variables aArity steps further away)
  | TAPlus   { aSucs :: Integer, aBody :: TTerm }
  -- ^ n+k pattern
  | TALit    { aLit :: Literal,   aBody:: TTerm }
  deriving (Typeable, Show, Eq, Ord)

data TError
  = TPatternMatchFailure QName -- function name
  deriving (Typeable, Show, Eq, Ord)
