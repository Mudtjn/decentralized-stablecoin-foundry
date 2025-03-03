// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

// this contract is to keep check that the feed is working alright
// any malfunction in feed does not break stablecoin
// If price is stale, the function will revert, and render DSCEngine unusable
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePriceData(); 
    uint256 private constant TIMEOUT = 3 hours; 

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns 
    (uint80 , int256 , uint256 , uint256, uint80 ) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
             = priceFeed.latestRoundData(); 
        uint256 timeElapsed = block.timestamp - updatedAt; 
        if(timeElapsed > TIMEOUT) revert OracleLib__StalePriceData(); 
        return (roundId, answer, startedAt, updatedAt, answeredInRound); 
    }
}