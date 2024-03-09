pragma solidity 0.8.13;

import "solmate/tokens/ERC20.sol";
import "./plugins/LimitPlugin.sol";
import "./plugins/ExecutionHelper.sol";

/**
 * @title SuperToken
 * @notice An ERC20 contract enabling bridging a token to its sibling chains.
 * @dev This contract implements ISuperTokenOrVault to support message bridging through IMessageBridge compliant contracts.
 */
contract LimitExecutionHook is LimitPlugin, ExecutionHelper {
    /**
     * @notice Constructor for creating a new SuperToken.
     * @param owner_ Owner of this contract.
     */
    constructor(
        address owner_,
        address vaultOrToken_
    ) HookBase(owner_, vaultOrToken_) {}

    // /**
    //  * @dev This function calls the srcHookCall function of the connector contract,
    //  * passing in the receiver, amount, siblingChainSlug, extradata, and msg.sender, and returns
    //  * the updated receiver, amount, and extradata.
    //  * @param receiver_ The receiver of the funds.
    //  * @param amount_ The amount of funds.
    //  * @param siblingChainSlug_ The sibling chain identifier.
    //  * @param payload_ Payload data to be passed to the connector contract.
    //  * @return updatedReceiver The updated receiver of the funds.
    //  * @return updatedAmount The updated amount of funds.
    //  * @return updatedExtradata The updated extradata.
    //  */
    function srcHookCall(
        SrcHookCallParams calldata params_
    ) external isVaultOrToken returns (TransferInfo memory) {
        _limitSrcHook(params_.connector, params_.transferInfo.amount);
        return params_.transferInfo;
    }

    // /**
    //  * @notice This function is called before the execution of a destination hook.
    //  * @dev It checks if the sibling chain is supported, consumes a part of the limit, and prepares post-hook data.
    //  * @param receiver_ The receiver of the funds.
    //  * @param amount_ The amount of funds.
    //  * @param siblingChainSlug_ The unique identifier of the sibling chain.
    //  * @param connector_ The address of the bridge contract.
    //  * @param extradata_ Additional data to be passed to the connector contract.
    //  * @param connectorCache_ Sibling chain cache containing pending amount information.
    //  * @return updatedReceiver The updated receiver of the funds.
    //  * @return consumedAmount The amount consumed from the limit.
    //  * @return postHookData The post-hook data to be processed after the hook execution.
    //  */
    function dstPreHookCall(
        DstPreHookCallParams calldata params_
    )
        external
        isVaultOrToken
        returns (bytes memory postHookData, TransferInfo memory transferInfo)
    {
        (uint256 consumedAmount, uint256 pendingAmount) = _limitDstHook(
            params_.connector,
            params_.transferInfo.amount
        );
        postHookData = abi.encode(consumedAmount, pendingAmount);
        transferInfo = params_.transferInfo;
        transferInfo.amount = consumedAmount;
    }

    // /**
    //  * @notice Handles post-hook logic after the execution of a destination hook.
    //  * @dev This function processes post-hook data to update the identifier cache and sibling chain cache.
    //  * @param receiver_ The receiver of the funds.
    //  * @param amount_ The amount of funds.
    //  * @param siblingChainSlug_ The unique identifier of the sibling chain.
    //  * @param connector_ The address of the bridge contract.
    //  * @param extradata_ Additional data passed to the connector contract.
    //  * @param postHookData_ The post-hook data containing consumed and pending amounts.
    //  * @param connectorCache_ Sibling chain cache containing pending amount information.
    //  * @return newIdentifierCache The updated identifier cache.
    //  * @return newConnectorCache The updated sibling chain cache.
    //  */
    function dstPostHookCall(
        DstPostHookCallParams calldata params_
    ) external isVaultOrToken returns (CacheData memory cacheData) {
        bytes memory execPayload = params_.transferInfo.data;

        (uint256 consumedAmount, uint256 pendingAmount) = abi.decode(
            params_.postHookData,
            (uint256, uint256)
        );

        uint256 connectorPendingAmount = abi.decode(
            params_.connectorCache,
            (uint256)
        );
        if (pendingAmount > 0) {
            cacheData.connectorCache = abi.encode(
                connectorPendingAmount + pendingAmount
            );
            // if pending amount is more than 0, payload is cached
            if (execPayload.length > 0) {
                cacheData.identifierCache = abi.encode(
                    params_.transferInfo.receiver,
                    pendingAmount,
                    params_.connector,
                    execPayload
                );
            } else {
                cacheData.identifierCache = abi.encode(
                    params_.transferInfo.receiver,
                    pendingAmount,
                    params_.connector,
                    bytes("")
                );
            }

            // emit TokensPending(
            //     siblingChainSlug_,
            //     receiver_,
            //     pendingAmount,
            //     pendingMints[siblingChainSlug_][receiver_][identifier],
            //     identifier
            // );
        } else if (execPayload.length > 0) {
            // execute
            bool success = _execute(params_.transferInfo.receiver, execPayload);

            if (success) cacheData.identifierCache = new bytes(0);
            else {
                cacheData.identifierCache = abi.encode(
                    params_.transferInfo.receiver,
                    0,
                    params_.connector,
                    execPayload
                );
            }

            cacheData.connectorCache = params_.connectorCache;
        }
    }

    // /**
    //  * @notice Handles pre-retry hook logic before execution.
    //  * @dev This function can be used to mint funds which were in a pending state due to limits.
    //  * @param siblingChainSlug_ The unique identifier of the sibling chain.
    //  * @param identifierCache_ Identifier cache containing pending mint information.
    //  * @param connectorCache_ Sibling chain cache containing pending amount information.
    //  * @return updatedReceiver The updated receiver of the funds.
    //  * @return consumedAmount The amount consumed from the limit.
    //  * @return postRetryHookData The post-hook data to be processed after the retry hook execution.
    //  */
    function preRetryHook(
        PreRetryHookCallParams calldata params_
    )
        external
        isVaultOrToken
        returns (
            bytes memory postRetryHookData,
            TransferInfo memory transferInfo
        )
    {
        (
            address receiver,
            uint256 pendingMint,
            address connector,
            bytes memory execPayload
        ) = abi.decode(
                params_.cacheData.identifierCache,
                (address, uint256, address, bytes)
            );

        if (connector != params_.connector) revert InvalidConnector();

        (uint256 consumedAmount, uint256 pendingAmount) = _limitDstHook(
            params_.connector,
            pendingMint
        );

        postRetryHookData = abi.encode(receiver, consumedAmount, pendingAmount);
        transferInfo = TransferInfo(receiver, consumedAmount, bytes(""));
    }

    // /**
    //  * @notice Handles post-retry hook logic after execution.
    //  * @dev This function updates the identifier cache and sibling chain cache based on the post-hook data.
    //  * @param siblingChainSlug_ The unique identifier of the sibling chain.
    //  * @param identifierCache_ Identifier cache containing pending mint information.
    //  * @param connectorCache_ Sibling chain cache containing pending amount information.
    //  * @param postRetryHookData_ The post-hook data containing updated receiver and consumed/pending amounts.
    //  * @return newIdentifierCache The updated identifier cache.
    //  * @return newConnectorCache The updated sibling chain cache.
    //  */
    function postRetryHook(
        PostRetryHookCallParams calldata params_
    ) external isVaultOrToken returns (CacheData memory cacheData) {
        (
            ,
            uint256 pendingMint,
            address connector,
            bytes memory execPayload
        ) = abi.decode(
                params_.cacheData.identifierCache,
                (address, uint256, address, bytes)
            );

        (address receiver, uint256 consumedAmount, uint256 pendingAmount) = abi
            .decode(params_.postRetryHookData, (address, uint256, uint256));

        if (pendingAmount == 0 && receiver != address(0)) {
            // receiver is not an input from user, can receiver check
            // no connector check required here, as already done in preRetryHook call in same tx

            // execute
            bool success = _execute(receiver, execPayload);
            if (success) cacheData.identifierCache = new bytes(0);
            else
                cacheData.identifierCache = abi.encode(
                    receiver,
                    0,
                    connector,
                    execPayload
                );
        }
        uint256 connectorPendingAmount = abi.decode(
            params_.cacheData.connectorCache,
            (uint256)
        );

        cacheData.connectorCache = abi.encode(
            connectorPendingAmount - consumedAmount
        );
    }
}
