// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title  Pool LP Token
 * @notice PoolToken is the lp token for naughtyPair
 *         The address is the same as the pair address
 */
contract PoolLPToken is ERC20("Naughty Pool LP", "NLP") {
    function LPMint(address _account, uint256 _amount) internal {
        _mint(_account, _amount);
    }

    function LPBurn(address _account, uint256 _amount) internal {
        _burn(_account, _amount);
    }

    function LPBalanceOf(address _account) public view returns (uint256) {
        return balanceOf(_account);
    }
}
