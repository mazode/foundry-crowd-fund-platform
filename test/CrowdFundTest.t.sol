// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CrowdFund.sol";

contract MockERC20 is IERC20 {
    string public name = "Test token";
    string public symbol = "TST";
    uint256 public decimals = 18;
    uint256 public totalSupply = 1_000_000 ether;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract CrowdFundTest is Test {
    CrowdFund crowdFund;
    MockERC20 token;

    function setUp() public {
        token = new MockERC20();
        crowdFund = new CrowdFund(address(token));
    }

    function testCreateCampaign() public {
        crowdFund.createCampaign("Campaign 1", "A test campaign", 100 ether, 7 days);

        (address creator, string memory title,, uint256 goal,,,) = crowdFund.campaigns(1);
        assertEq(creator, address(this), "Creator should be this contract");
        assertEq(keccak256(bytes(title)), keccak256(bytes("Campaign 1")), "Title mismatch");
        assertEq(goal, 100 ether, "Goal mismatch");
    }

    function testPledge() public {
        crowdFund.createCampaign("Campaign 1", "A test campaign", 100 ether, 7 days);

        token.approve(address(crowdFund), 50 ether);

        crowdFund.pledge(1, 50 ether);

        (,,,,, uint256 totalPldged,) = crowdFund.campaigns(1);
        assertEq(totalPldged, 50 ether, "Pledged amount mismatch");
    }

    function testUnpledge() public {
        crowdFund.createCampaign("Campaign 1", "A test campaign", 100 ether, 7 days);

        token.approve(address(crowdFund), 50 ether);

        crowdFund.pledge(1, 50 ether);

        crowdFund.unpledge(1, 20 ether);

        (,,,,, uint256 totalPledged,) = crowdFund.campaigns(1);
        assertEq(totalPledged, 30 ether, "Unpledged amount mismatch");
    }

    function testClaim() public {
        crowdFund.createCampaign("Campaign 1", "A test campaign", 100 ether, 7 days);

        token.approve(address(crowdFund), 100 ether);
        crowdFund.pledge(1, 100 ether);

        vm.warp(block.timestamp + 8 days);

        crowdFund.claim(1);

        (,,,,,, bool claimed) = crowdFund.campaigns(1);
        assertTrue(claimed, "Funds should be claimed");
    }

    function testRefund() public {
        crowdFund.createCampaign("Campaign 1", "A test campaign", 100 ether, 7 days);

        token.approve(address(crowdFund), 50 ether);
        crowdFund.pledge(1, 50 ether);

        vm.warp(block.timestamp + 8 days);

        crowdFund.refund(1);

        uint256 contribution = crowdFund.contributions(1, address(this));
        assertEq(contribution, 0, "Contribution should be refunded");
    }
}
