{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Main where

import Control.Monad.Except (ExceptT, MonadError, runExceptT, throwError)
import Control.Monad.IO.Class (MonadIO, liftIO)

import Options.Applicative

import System.Exit (exitFailure)

import Language.LXDFile (parseFile)
import qualified System.LXD.LXDFile as LXDFile

data Command = BuildCommand FilePath String FilePath -- ^ LXDFile, image tag and base directory
             | LaunchCommand String [FilePath]       -- ^ Image, list of init scripts

newtype CmdT m a = CmdT { runCmdT :: ExceptT String m a }
                 deriving (Functor, Applicative, Monad, MonadIO, MonadError String)

buildCmd :: Mod CommandFields Command
buildCmd =
    command "build" $ info (helper <*> cmd') $ progDesc "build an LXD image using an LXDFile"
 where
    cmd' = BuildCommand <$> strOption (short 'f' <> metavar "LXDFILE" <> value "lxdfile" <> help "location of the lxdfile")
                        <*> strArgument (metavar "NAME" <> help "name of the newly built image")
                        <*> strArgument (metavar "DIR" <> value "." <> help "base directory")

launchCmd :: Mod CommandFields Command
launchCmd =
    command "launch" $ info (helper <*> cmd') $ progDesc "launch an LXD image with init scripts"
  where
    cmd' = LaunchCommand <$> strArgument (metavar "IMAGE" <> help "name of an LXD iamge")
                         <*> many (strOption $ short 'i' <> metavar "SCRIPT" <> help "init script to execute after launch")

subcommand :: Parser Command
subcommand = subparser (buildCmd <> launchCmd)

main :: IO ()
main =
    execParser opts >>= run
  where
    opts = info (helper <*> subcommand) $ progDesc "Automatically build and manage LXD images and containers."
    run (BuildCommand lxdfile tag base) = cmd $ build lxdfile tag base
    run (LaunchCommand image inits) = cmd $ launch image inits

cmd :: CmdT IO () -> IO ()
cmd action' = do
    x <- runExceptT $ runCmdT action'
    case x of Right () -> return ()
              Left e -> do
                putStrLn $ "error: " ++ e
                exitFailure

build :: (MonadIO m, MonadError String m) => FilePath -> String -> FilePath -> m ()
build fp name dir = do
    lxdfile <- liftIO (parseFile fp) >>= orErr "parse error"
    LXDFile.build lxdfile name dir
  where
    orErr pref = either (showErr pref) return
    showErr pref e = throwError $ pref ++ ": " ++ show e

launch :: (MonadIO m, MonadError String m) => String -> [FilePath] ->  m ()
launch = undefined
