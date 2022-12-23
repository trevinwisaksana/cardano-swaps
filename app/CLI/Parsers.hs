module CLI.Parsers
(
  parseCommand,
  Command (..),
  AdvancedCmd (..),
  Asset (..),
  RawAsset (..),
  SwapDatumInfo (..),
  SwapScriptCmd (..),
  StakingScriptCmd (..),
  BeaconCmd (..),
  Output (..),
) where

import Options.Applicative
import Data.ByteString (ByteString)

import CardanoSwaps

-- | Used for most commands
data Asset = Ada | Asset !CurrencySymbol !TokenName

-- | Used to generate beacon token name
data RawAsset = RawAda | RawAsset !ByteString !ByteString

-- | For when saving to file is optional
data Output = StdOut | File !FilePath

data SwapDatumInfo
  = SwapDatum !Price
  | SwapDatumUtxos !FilePath  -- ^ JSON file for UtxoPriceInfo to be used with calcWeightedPrice
  | SwapDatumUtxosTemplate  -- ^ If a JSON template file is necessary

data Command
  = SwapScript SwapScriptCmd
  | StakingScript StakingScriptCmd
  | Beacon BeaconCmd
  | Advanced AdvancedCmd !FilePath
  -- | Query

data SwapScriptCmd
  = CreateSwapScript !PaymentPubKeyHash !Asset !Asset !FilePath
  | CreateSwapDatum !SwapDatumInfo !FilePath
  | CreateSwapRedeemer !Action !FilePath

data StakingScriptCmd
  = CreateStakingScript !PaymentPubKeyHash (Maybe Asset) (Maybe Asset) !FilePath
  | CreateStakingRedeemer !FilePath

data BeaconCmd
  = GenerateBeaconTokenName !RawAsset !RawAsset !Output
  | ExportBeaconPolicyId !Output
  | CreateBeaconRedeemer !BeaconRedeemer !FilePath
  | CreateBeaconDatum !FilePath  -- ^ For use with the beacon vault script

data AdvancedCmd
  = ExportBeaconPolicyScript
  | ExportBeaconVaultScript


parseCommand :: Parser Command
parseCommand = hsubparser $
  command "swap-script"
    (info parseSwapScriptCmd $ progDesc "Commands for using a swap script.") <>
  command "staking-script"
    (info parseStakingScriptCmd $ progDesc "Commands for using a staking script.") <>
  command "beacon"
    (info parseBeaconCmd $ progDesc "Commands for using beacons.") <>
  command "advanced"
    (info parseAdvancedCmd $ progDesc "Advanced commands for developers.")

parseSwapScriptCmd :: Parser Command
parseSwapScriptCmd = fmap SwapScript . hsubparser $
  command "create-script"
    (info pCreateSwapScript $ progDesc "Create a personal swap script.") <>
  command "create-datum"
    (info pCreateSwapDatum $ progDesc "Create a datum for a swap script.") <>
  command "create-redeemer"
    (info pCreateSwapRedeemer $ progDesc "Create a redeemer for a swap script.")

parseStakingScriptCmd :: Parser Command
parseStakingScriptCmd = fmap StakingScript . hsubparser $
  command "create-script"
    (info pCreateStakingScript $ progDesc "Create a personal staking script.") <>
  command "create-redeemer"
    (info pCreateStakingRedeemer $ progDesc "Create a redeemer for a staking script.")

parseBeaconCmd :: Parser Command
parseBeaconCmd = fmap Beacon . hsubparser $
  command "generate-token-name"
    (info pGenerateBeaconTokenName $ progDesc "Generate a beacon token name.") <>
  command "policy-id"
    (info pExportBeaconPolicyId $ progDesc "Export the beacon policy id (Currency Symbol).") <>
  command "create-redeemer"
    (info pCreateBeaconRedeemer $ progDesc "Create a redeemer for minting/burning beacons.") <>
  command "create-datum"
    (info pCreateBeaconDatum $ 
      progDesc "Create a datum for minting beacons. Used with the beacon deposit vault.")

parseAdvancedCmd :: Parser Command
parseAdvancedCmd =
   Advanced
     <$> (pBeaconPolicy <|> pBeaconVaultScript)
     <*> pOutputFile
  where
    pBeaconPolicy :: Parser AdvancedCmd
    pBeaconPolicy = flag' ExportBeaconPolicyScript
      (  long "beacon-policy-script"
      <> help "Export the beacon policy script."
      )

    pBeaconVaultScript :: Parser AdvancedCmd
    pBeaconVaultScript = flag' ExportBeaconVaultScript
      (  long "beacon-vault-script"
      <> help "Export the beacon vault script."
      )

pGenerateBeaconTokenName :: Parser BeaconCmd
pGenerateBeaconTokenName =
  GenerateBeaconTokenName
    <$> pOfferedRaw
    <*> pAskedRaw
    <*> pOutput

pExportBeaconPolicyId :: Parser BeaconCmd
pExportBeaconPolicyId = ExportBeaconPolicyId <$> pOutput

pCreateBeaconDatum :: Parser BeaconCmd
pCreateBeaconDatum = CreateBeaconDatum <$> pOutputFile

pCreateBeaconRedeemer :: Parser BeaconCmd
pCreateBeaconRedeemer =
   CreateBeaconRedeemer
     <$> (pMint <|> pBurn)
     <*> pOutputFile
  where
    pMint :: Parser BeaconRedeemer
    pMint = MintBeacon <$> option (eitherReader readTokenName)
      (  long "mint-beacon"
      <> metavar "STRING"
      <> help "Mint a beacon with the supplied token name (in hexidecimal)."
      )

    pBurn :: Parser BeaconRedeemer
    pBurn = BurnBeacon <$> option (eitherReader readTokenName)
      (  long "burn-beacon"
      <> metavar "STRING"
      <> help "Burn a beacon with the supplied token name (in hexidecimal)."
      )

pCreateStakingScript :: Parser StakingScriptCmd
pCreateStakingScript =
  CreateStakingScript
    <$> pOwnerPubKeyHash
    <*> optional pOffered
    <*> optional pAsked
    <*> pOutputFile

pCreateStakingRedeemer :: Parser StakingScriptCmd
pCreateStakingRedeemer = CreateStakingRedeemer <$> pOutputFile

pCreateSwapScript :: Parser SwapScriptCmd
pCreateSwapScript =
  CreateSwapScript
    <$> pOwnerPubKeyHash
    <*> pOffered
    <*> pAsked
    <*> pOutputFile

pCreateSwapDatum :: Parser SwapScriptCmd
pCreateSwapDatum = 
    CreateSwapDatum 
      <$> (pSwapDatum <|> pSwapUtxoInfo <|> pTemplate) 
      <*> pOutputFile
  where
    pSwapPrice :: Parser Price
    pSwapPrice = fromGHC . (toRational :: Double -> Rational) <$> option auto
      (  long "swap-price"
      <> metavar "DECIMAL"
      <> help "The swap price (asked asset / offered asset)."
      )

    pSwapDatum :: Parser SwapDatumInfo
    pSwapDatum = SwapDatum <$> pSwapPrice

    pSwapUtxoInfo :: Parser SwapDatumInfo
    pSwapUtxoInfo = SwapDatumUtxos <$> strOption
      (  long "calc-swap-price-from-file"
      <> metavar "JSON FILE"
      <> help "Calculate swap price from a JSON file of utxo amounts, price numerators, and price denominators."
      )

    pTemplate :: Parser SwapDatumInfo
    pTemplate = flag' SwapDatumUtxosTemplate
      (  long "swap-price-file-template"
      <> help "Create a template JSON file for use with calc-swap-price-from-file."
      )

pCreateSwapRedeemer :: Parser SwapScriptCmd
pCreateSwapRedeemer =
    CreateSwapRedeemer
      <$> (pClose <|> pSwap <|> pInfo <|> fmap UpdatePrices pUpdateSwapPrice)
      <*> pOutputFile
  where
    pClose :: Parser Action
    pClose = flag' Close
      (  long "close-swap"
      <> help "Remove all assets and reference scripts from the swap address."
      )

    pSwap :: Parser Action
    pSwap = flag' Swap
      (  long "swap-assets" 
      <> help "Swap with assets at a swap address."
      )

    pInfo :: Parser Action
    pInfo = flag' Info
      (  long "owner-info"
      <> help "Get the owner info needed to verify contract integrity."
      )

    pUpdateSwapPrice :: Parser Price
    pUpdateSwapPrice = fromGHC . (toRational :: Double -> Rational) <$> option auto
      (  long "update-swap-price"
      <> metavar "DECIMAL"
      <> help "Change the swap price (asked asset / offered asset)."
      )



pOwnerPubKeyHash :: Parser PaymentPubKeyHash
pOwnerPubKeyHash = option (eitherReader readPubKeyHash)
  (  long "owner-payment-key-hash" 
  <> metavar "STRING" 
  <> help "The owner's payment key hash."
  )

pOutputFile :: Parser FilePath
pOutputFile = strOption
  (  long "out-file"
  <> metavar "FILE"
  <> help "The output file."
  <> completer (bashCompleter "file")
  )

pAsked :: Parser Asset
pAsked = pAskedAda <|> (Asset <$> pAskedCurrencySymbol <*> pAskedTokenName)
  where
    pAskedAda :: Parser Asset
    pAskedAda = flag' Ada
      (  long "asked-asset-is-ada"
      <> help "The asset asked for is ADA"
      )

    pAskedCurrencySymbol :: Parser CurrencySymbol
    pAskedCurrencySymbol = option (eitherReader readCurrencySymbol)
      (  long "asked-asset-policy-id" 
      <> metavar "STRING" 
      <> help "The policy id of the asked asset."
      )

    pAskedTokenName :: Parser TokenName
    pAskedTokenName = option (eitherReader readTokenName)
      (  long "asked-asset-token-name"
      <> metavar "STRING"
      <> help "The token name (in hexidecimal) of the asked asset."
      )

pOffered :: Parser Asset
pOffered = pOfferedAda <|> (Asset <$> pOfferedCurrencySymbol <*> pOfferedTokenName)
  where
    pOfferedAda :: Parser Asset
    pOfferedAda = flag' Ada
      (  long "offered-asset-is-ada"
      <> help "The asset being offered is ADA"
      )

    pOfferedCurrencySymbol :: Parser CurrencySymbol
    pOfferedCurrencySymbol = option (eitherReader readCurrencySymbol)
      (  long "offered-asset-policy-id" 
      <> metavar "STRING" 
      <> help "The policy id of the offered asset."
      )

    pOfferedTokenName :: Parser TokenName
    pOfferedTokenName = option (eitherReader readTokenName)
      (  long "offered-asset-token-name"
      <> metavar "STRING"
      <> help "The token name (in hexidecimal) of the offered asset."
      )

pAskedRaw :: Parser RawAsset
pAskedRaw = pAskedAda <|> (RawAsset <$> pAskedCurrencySymbol <*> pAskedTokenName)
  where
    pAskedAda :: Parser RawAsset
    pAskedAda = flag' RawAda
      (  long "asked-asset-is-ada"
      <> help "The asset asked for is ADA"
      )

    pAskedCurrencySymbol :: Parser ByteString
    pAskedCurrencySymbol = strOption
      (  long "asked-asset-policy-id" 
      <> metavar "STRING" 
      <> help "The policy id of the asked asset."
      )

    pAskedTokenName :: Parser ByteString
    pAskedTokenName = strOption
      (  long "asked-asset-token-name"
      <> metavar "STRING"
      <> help "The token name (in hexidecimal) of the asked asset."
      )

pOfferedRaw :: Parser RawAsset
pOfferedRaw = pOfferedAda <|> (RawAsset <$> pOfferedCurrencySymbol <*> pOfferedTokenName)
  where
    pOfferedAda :: Parser RawAsset
    pOfferedAda = flag' RawAda
      (  long "offered-asset-is-ada"
      <> help "The asset being offered is ADA"
      )

    pOfferedCurrencySymbol :: Parser ByteString
    pOfferedCurrencySymbol = strOption
      (  long "offered-asset-policy-id" 
      <> metavar "STRING" 
      <> help "The policy id of the offered asset."
      )

    pOfferedTokenName :: Parser ByteString
    pOfferedTokenName = strOption
      (  long "offered-asset-token-name"
      <> metavar "STRING"
      <> help "The token name (in hexidecimal) of the offered asset."
      )

pStdOut :: Parser Output
pStdOut = flag' StdOut
  (  long "stdout"
  <> help "Display to stdout."
  )

pOutput :: Parser Output
pOutput = pStdOut <|> File <$> pOutputFile




-- parseQuery :: Parser Command
-- parseQuery = 
--    Query
--      <$> pTargetCurrencySymbol
--      <*> pTargetTokenName
--      <*> pUserCurrencySymbol
--      <*> pUserTokenName
--      <*> (pMainnet <|> pTestnet)
--   where
--     pTargetCurrencySymbol :: Parser CurrencySymbol
--     pTargetCurrencySymbol = option (eitherReader readCurrencySymbol)
--       (  long "target-asset-policy-id" 
--       <> metavar "STRING" 
--       <> help "The policy id of the target asset."
--       )

--     pTargetTokenName :: Parser TokenName
--     pTargetTokenName = option (eitherReader readTokenName)
--       (  long "target-asset-token-name"
--       <> metavar "STRING"
--       <> help "The token name (in hexidecimal) of the target asset."
--       )

--     pUserCurrencySymbol :: Parser CurrencySymbol
--     pUserCurrencySymbol = option (eitherReader readCurrencySymbol)
--       (  long "user-asset-policy-id" 
--       <> metavar "STRING" 
--       <> help "The policy id of the asset you will give to the swap address."
--       )

--     pUserTokenName :: Parser TokenName
--     pUserTokenName = option (eitherReader readTokenName)
--       (  long "user-asset-token-name"
--       <> metavar "STRING"
--       <> help "The token name (in hexidecimal) of the asset you will give to the swap address."
--       )
    
--     pMainnet :: Parser Network
--     pMainnet = flag' Mainnet
--       (  long "mainnet"
--       <> help "Query the Cardano Mainnet using the Koios REST api."
--       )
    
--     pTestnet :: Parser Network
--     pTestnet = PreProdTestnet . BlockfrostApiKey <$> strOption
--       (  long "preprod-testnet"
--       <> metavar "STRING"
--       <> help "Query the Cardano PreProduction Testnet using the Blockfrost REST api and the supplied api key."
--       )