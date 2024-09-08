// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract CrowdFund {
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        string description,
        uint256 goal,
        uint256 deadline,
        uint256 totalPledged
    );
    event Pledged(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event Unpledged(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignClaimed(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 totalPledged;
        bool claimed;
    }

    IERC20 public immutable token;
    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    constructor(address _token) {
        require(_token != address(0), "Invalid addrss");
        token = IERC20(_token);
    }

    // Create Campaign
    function createCampaign(string memory _title, string memory _description, uint256 _goal, uint256 _duration)
        external
    {
        require(bytes(_title).length > 0, "Title can't be empty");
        require(bytes(_description).length > 0, "Description can't be empty");
        require(_duration > 0, "Duration should be greater than zero");
        require(_goal > 0, "Goal should be greater than zero");

        campaignCount++;
        uint256 deadline = block.timestamp + _duration;

        Campaign storage newCampaign = campaigns[campaignCount];
        newCampaign.creator = msg.sender;
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goal = _goal;
        newCampaign.deadline = deadline;
        newCampaign.totalPledged = 0;
        newCampaign.claimed = false;

        emit CampaignCreated(campaignCount, msg.sender, _title, _description, _goal, deadline, 0);
    }
    // Pledge Funds to a campaign

    function pledge(uint256 _campaignId, uint256 _amount) external {
        require(_amount > 0, "Pledge amount should be greater than zero");
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(block.timestamp < campaign.deadline, "Campaign has ended");

        campaign.totalPledged += _amount;
        contributions[_campaignId][msg.sender] += _amount;
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        emit Pledged(_campaignId, msg.sender, _amount);
    }
    // Unpledge funds to a campaign

    function unpledge(uint256 _campaignId, uint256 _amount) external {
        require(_amount > 0, "Pledge amount should be greater than zero");
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(block.timestamp < campaign.deadline, "Campaign has ended");

        campaign.totalPledged -= _amount;
        contributions[_campaignId][msg.sender] -= _amount;
        require(token.transfer(msg.sender, _amount), "Token transfer failed");

        emit Unpledged(_campaignId, msg.sender, _amount);
    }
    // Claim the funds by the campaign creator

    function claim(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(campaign.creator == msg.sender, "Only creator can claim funds");
        require(block.timestamp > campaign.deadline, "Campaign is still active");
        require(campaign.totalPledged >= campaign.goal, "Funding goal not achieved");
        require(!campaign.claimed, "Funds already claimed");

        campaign.claimed = true;
        require(token.transfer(campaign.creator, campaign.totalPledged), "Token transfer failed");

        emit CampaignClaimed(_campaignId, msg.sender, campaign.totalPledged);
    }
    // Refund the tokens to the contributors if goals is not reached

    function refund(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(block.timestamp > campaign.deadline, "Campaign is still active");
        require(campaign.totalPledged < campaign.goal, "Funding goal achieved");

        uint256 contributedAmount = contributions[_campaignId][msg.sender];
        require(contributedAmount > 0, "No contribution to refund");

        contributions[_campaignId][msg.sender] = 0;
        require(token.transfer(msg.sender, contributedAmount), "Token transfer failed");

        emit RefundIssued(_campaignId, msg.sender, contributedAmount);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
