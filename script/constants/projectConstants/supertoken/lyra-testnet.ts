import {
  ChainSlug,
  DeploymentMode,
  IntegrationTypes,
} from "@socket.tech/dl-core";
import { Hooks, ProjectConstants, Tokens } from "../../../../src";
import { getSocketOwner } from "../../config";

const pc: ProjectConstants = {
  [DeploymentMode.PROD]: {
    [Tokens.WEETHC]: {
      vaultChains: [ChainSlug.LYRA_TESTNET],
      controllerChains: [
        ChainSlug.ARBITRUM_SEPOLIA,
        ChainSlug.OPTIMISM_SEPOLIA,
      ],
      superTokenInfo: {
        name: "Wrapped eETH Covered Call",
        symbol: "weETHC",
        decimals: 18,
        initialSupplyOwner: "0x0000000000000000000000000000000000000000",
        owner: getSocketOwner(),
        initialSupply: 0,
      } as any, // set fields as undefined so token isn't deployed
      hook: {
        hookType: Hooks.LYRA_TSA_WITHDRAW_HOOK,
        limitsAndPoolId: {
          [ChainSlug.LYRA_TESTNET]: {
            [IntegrationTypes.fast]: {
              sendingLimit: "1000000",
              receivingLimit: "1000000",
            },
          },
          [ChainSlug.ARBITRUM_SEPOLIA]: {
            [IntegrationTypes.fast]: {
              sendingLimit: "1000000",
              receivingLimit: "1000000",
              poolCount: 1,
            },
          },
          [ChainSlug.OPTIMISM_SEPOLIA]: {
            [IntegrationTypes.fast]: {
              sendingLimit: "1000000",
              receivingLimit: "1000000",
              poolCount: 1,
            },
          },
        },
      },
    },
    [Tokens.RSWETHC]: {
      vaultChains: [ChainSlug.LYRA_TESTNET],
      controllerChains: [ChainSlug.ARBITRUM_SEPOLIA],
      superTokenInfo: {
        name: "rswETH Covered Call",
        symbol: "rswETHC",
        decimals: 18,
        initialSupplyOwner: "0x0000000000000000000000000000000000000000",
        owner: getSocketOwner(),
        initialSupply: 0,
      } as any, // set fields as undefined so token isn't deployed
      hook: {
        hookType: Hooks.LYRA_TSA_WITHDRAW_HOOK,
        limitsAndPoolId: {
          [ChainSlug.LYRA_TESTNET]: {
            [IntegrationTypes.fast]: {
              sendingLimit: "1000000",
              receivingLimit: "1000000",
            },
          },
          [ChainSlug.ARBITRUM_SEPOLIA]: {
            [IntegrationTypes.fast]: {
              sendingLimit: "1000000",
              receivingLimit: "1000000",
              poolCount: 1,
            },
          },
        },
      },
    },
  },
};

export = pc;
