// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // mapping token address -> staker address -> amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    // how many unique tokens each address has staked
    mapping(address => uint256) public uniqueTokensStaked;
    // map token to associated price feed
    mapping(address => address) public tokenPriceFeedMapping;
    // list of all stakers on platform
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public dappToken;

    // stake tokens
    // unstake tokens
    // issueTokens (reward) eg. 100 ETH 1:1 for every 1 ETH, we give 1 DAPP
    // add allowed tokens
    // get Value of tokens in USD

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        // set price feed associated with token
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function issueTokens() public onlyOwner {
        // Issue token to all stakers
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            // Send token rewards based on value locked
            uint256 userTotalValue = getUserTotalValue(recipient);

            // transfer from IERC used as this contract holds tokens
            dappToken.transfer(recipient, userTotalValue);
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "No tokens staked.");
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleTokenValue(
                    _user,
                    allowedTokens[allowedTokensIndex]
                );
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token)
        public
        view
        returns (uint256)
    {
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        // Find value of token staked for 1:1 return = price of token * staking balance of token of user
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return ((stakingBalance[_token][_user] * price) / (10**decimals));
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        // Price Feed Address
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();

        // fund out number of decimals to match units
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    function stakeTokens(uint256 _amount, address _token) public {
        // what tokens can be staked?
        // how much can be staked?
        require(_amount > 0, "Amount must be more than 0.");
        require(tokenIsAllowed(_token), "Token is currently not allowed.");

        //transferFrom from function from ERC20 since we dont own the tokens
        // ABI via interface and address:
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        // issue rewards only if its their first unique token and they are not on list
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function unstakeTokens(address _token) public {
        // fetch staking balance
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0.");
        IERC20(_token).transfer(msg.sender, balance);

        // update balance to 0
        stakingBalance[_token][msg.sender] = 0;

        // update how many unique tokens they have
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;

        // Fix for stakers appearing twice in array receiving 2x awards
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            if (stakers[stakersIndex] == msg.sender) {
                stakers[stakersIndex] = stakers[stakers.length - 1];
                stakers.pop();
            }
        }
        // Update stakers array to remove this user if they do not have anything staked later
    }

    // Find out how many unique tokens a user has
    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    // add allowed tokens
    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    // is token allowed?
    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
            return false;
        }
    }
}
