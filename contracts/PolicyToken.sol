// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IPolicyToken.sol";

/**
 * @title  Policy Token
 * @notice This is the contract for token price policy token.
 *         It is a ERC20 token with an owner and a minter.
 *         The owner should be the deployer at first.
 *         The minter should be the policyCore contract.
 * @dev    It is different from the flight delay token.
 *         That is a ERC721 NFT and this is a ERC20 token.
 */
contract PolicyToken is ERC20, IPolicyToken {
    address public owner;

    address public minter;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC20(_name, _symbol) {
        owner = _owner;
        minter = _owner;
    }

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }

    /**
     * @notice Only the minter can mint
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "only minter can call this function");
        _;
    }

    /**
     * @notice Pass the minter role to a new address
     * @param _newMinter Address of new minter
     */
    function passMinterRole(address _newMinter) public onlyOwner {
        address oldMinter = minter;
        minter = _newMinter;
        emit MinterRoleChanged(oldMinter, _newMinter);
    }

    /**
     * @notice Mint some policy tokens
     * @param _account Address to receive the tokens
     * @param _amount Amount to be minted
     */
    function mint(address _account, uint256 _amount) public onlyMinter {
        _mint(_account, _amount);
    }

    /**
     * @notice Burn some policy tokens
     * @param _account Address to burn tokens
     * @param _amount Amount to be burned
     */
    function burn(address _account, uint256 _amount) public onlyMinter {
        _burn(_account, _amount);
    }
}
