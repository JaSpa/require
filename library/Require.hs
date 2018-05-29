module Require where

import Universum

import qualified Text.Megaparsec      as Megaparsec
import qualified Text.Megaparsec.Char as Megaparsec
import qualified Data.Text            as Text

newtype FileName   = FileName Text
newtype LineNumber = LineNumber Int
type Parser        = Megaparsec.Parsec Void Text


data RequireInfo = RequireInfo
  { riFullModuleName :: Text
  , riModuleAlias    :: Text
  , riImportedTypes  :: Maybe [Text]
  } deriving Show


requireMain :: IO ()
requireMain = undefined


autorequireMain :: IO ()
autorequireMain = undefined


transform :: Bool -> FileName -> Text -> Text -> Text
transform auorequireEnabled filename imports input
  | autorequireEnabled = transform' True filename imports input
  | noAutorequire  = transform' False filename imports input
  | otherwise      = transform' True filename imports input
 where
  noAutorequire = (length $ filter (\t -> "autorequire" `Text.isPrefixOf` t) $ lines input) == 0


transform' :: Bool -> FileName -> Text -> Text -> Text
transform' shouldPrepend filename prepended input =
  Text.lines input
  &   zip [1..]
  >>= prependAfterModuleLine
  &   filter (\(_, t) -> not $ "autorequire" `Text.isPrefixOf` t)
  <&> (\(ln, text) -> maybe (lineTag filename (LineNumber ln) <> text <> "\n") (renderImport filename (LineNumber ln)) $ Megaparsec.parseMaybe requireParser text )
  &   Text.concat
 where
  enumeratedPrepend ln
   | shouldPrepend = zip (repeat ln) (Text.lines prepended )
   | otherwise     = []
  prependAfterModuleLine (ln, text)
   | "where" `Text.isInfixOf` text = (ln, text) : enumeratedPrepend (ln)
   | otherwise                      = [(ln, text)]

lineTag :: FileName -> LineNumber -> Text
lineTag (FileName fn) (LineNumber ln) =
  "{-# LINE "
  <> show ln
  <> " \""
  <> fn
  <> "\" #-}\n"


renderImport :: FileName -> LineNumber -> RequireInfo -> Text
renderImport filename linenumber RequireInfo {..} =
  lineTag filename linenumber <> typesImport <> lineTag filename linenumber <> qualifiedImport
 where
  types = maybe (Text.takeWhileEnd (/= '.') riFullModuleName) (Text.intercalate ",") riImportedTypes
  typesImport = "import " <> riFullModuleName <> " (" <> types <> ")\n"
  qualifiedImport = "import qualified " <> riFullModuleName <> " as " <> riModuleAlias <> "\n"


requireParser :: Parser RequireInfo
requireParser = do
  void $ Megaparsec.string "require"
  void $ Megaparsec.space1
  module' <- Megaparsec.some (Megaparsec.alphaNumChar <|> Megaparsec.punctuationChar)
  void $ Megaparsec.space

  alias'  <- Megaparsec.try $ Megaparsec.option Nothing $ do
    void $ Megaparsec.string "as"
    void $ Megaparsec.space1
    Just <$> Megaparsec.some (Megaparsec.alphaNumChar)

  void $ Megaparsec.space

  types'  <- Megaparsec.option Nothing $ do
    void $ Megaparsec.char '('
    t' <- Megaparsec.some (Megaparsec.alphaNumChar <|> Megaparsec.char ',' <|> Megaparsec.char ' ')
    void $ Megaparsec.char ')'
    return $ Just t'

  return RequireInfo
    { riFullModuleName = toText $ module'
    , riModuleAlias    = maybe (Text.takeWhileEnd (/= '.') $ toText module') toText alias'
    , riImportedTypes  = fmap Text.strip <$> Text.splitOn "," <$> toText <$> types'
    }

