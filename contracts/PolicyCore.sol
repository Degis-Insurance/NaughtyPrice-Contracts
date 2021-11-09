// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/NaughtyLibrary.sol";

import "./interfaces/IPolicyToken.sol";

import "./interfaces/INaughtyRouter.sol";
import "./interfaces/INaughtyFactory.sol";

/**
 * @title PolicyCore
 * @notice 1. Deposit USDT and mint PolicyTokens
 *         2. Claim for payout with PolicyTokens
 */
contract PolicyCore {
    using SafeERC20 for IERC20;

    address public factory;
    address public router;

    address public owner;
    address public USDT;

    mapping(string => address) policyTokenAddressMapping; // Name => Address

    mapping(address => mapping(address => uint256)) userQuota; // User Address => Token Address => Quota Amount

    constructor(address _usdt) {
        USDT = _usdt;
        owner = msg.sender;
    }

    /**
     * @notice Deploy a new policy token and get the token address
     */
    function deployPolicyToken(string memory _tokenName)
        public
        returns (address)
    {
        address tokenAddress = INaughtyFactory(factory).deployPolicyToken(
            _tokenName
        );

        // Store the address in the mapping
        policyTokenAddressMapping[_tokenName] = tokenAddress;

        return tokenAddress;
    }

    function deployPool(address _tokenAddress) public returns (address) {
        address poolAddress = INaughtyFactory(factory).deployPool(
            _tokenAddress
        );
        return poolAddress;
    }

    /**
     * @notice Mint Policy Token 1:1 USDT
     *         The policy token need to be deployed first!
     */
    function mintPolicyToken(address _policyToken, uint256 _amount) public {
        IPolicyToken policyToken = IPolicyToken(_policyToken);

        require(
            IERC20(USDT).balanceOf(msg.sender) >= _amount,
            "user's USDT balance not sufficient"
        );

        IERC20(USDT).safeTransferFrom(msg.sender, address(this), _amount);

        policyToken.mint(msg.sender, _amount);

        userQuota[msg.sender][_policyToken] += _amount;
    }

    /**
     * @notice Claim policies
     */
    function claimPolicyToken(address _policyToken, uint256 _amount) public {
        IPolicyToken policyToken = IPolicyToken(_policyToken);

        require(
            IERC20(USDT).balanceOf(address(this)) >= _amount,
            "contract's USDT balance not sufficient"
        );

        IERC20(USDT).safeTransfer(msg.sender, _amount);

        policyToken.burn(msg.sender, _amount);

        userQuota[msg.sender][_policyToken] -= _amount;
    }
}
