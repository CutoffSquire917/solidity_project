// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 1. Counter
contract Counter {
    uint256 private count;

    function increment() public {
        count += 1;
    }

    function decrement() public {
        if (count > 0) {
            require(count > 0, "Counter cannot be negative");
            count -= 1;
        }
    }

    function getCount() public view returns (uint256) {
        return count;
    }
}

// 2. TodoList
contract TodoList {
    string[] private tasks;

    function addTask(string memory task) public {
        tasks.push(task);
    }

    function deleteTask(uint256 index) public {
        require(index > tasks.length - 1, "Index greater than length of array");
        delete tasks[index];
    }

    function getAllTasks() public view returns (string[] memory) {
        return tasks;
    }
}

// 3. SimpleMarket
contract SimpleMarket {
    struct Product {
        uint256 id;
        string name;
        uint256 price;
        address payable seller;
        bool isSold;
    }

    Product[] public products;
    uint256 public nextProductId;

    function addProduct(string memory name, uint256 price) public {
        require(price > 0, "Price must be greater than zero");
        products.push(
            Product(nextProductId, name, price, payable(msg.sender), false)
        );
        nextProductId++;
    }

    function buyProduct(uint256 id) public payable {
        require(id < products.length, "Product does not exist");
        Product storage product = products[id];

        require(!product.isSold, "Product is already sold");
        require(msg.value >= product.price, "Not enough ETH sent");

        product.isSold = true;
        product.seller.transfer(product.price);

        if (msg.value > product.price) {
            payable(msg.sender).transfer(msg.value - product.price);
        }
    }

    function getAllProducts() public view returns (Product[] memory) {
        return products;
    }
}

// 4. SimpleVoting
contract SimpleVoting {
    struct Candidate {
        string name;
        uint256 voteCount;
    }

    Candidate[] public candidates;
    mapping(address => bool) public hasVoted;

    constructor(string[] memory candidateNames) {
        for (uint256 i = 0; i < candidateNames.length; i++) {
            candidates.push(
                Candidate({name: candidateNames[i], voteCount: 0})
            );
        }
    }

    function vote(uint256 candidateIndex) public {
        require(!hasVoted[msg.sender], "You have already voted");
        require(candidateIndex < candidates.length, "Invalid candidate index");

        hasVoted[msg.sender] = true;
        candidates[candidateIndex].voteCount += 1;
    }

    function getResults() public view returns (Candidate[] memory) {
        return candidates;
    }
}

// 5. SubscriptionSystem
contract SubscriptionSystem {
    address public owner;
    uint256 public subscriptionPrice = 0.01 ether;
    uint256 public subscriptionDuration = 30 days;

    mapping(address => uint256) public subscriptionExpiration;

    constructor() {
        owner = msg.sender;
    }

    function subscribe() public payable {
        require(
            msg.value >= subscriptionPrice,
            "Insufficient funds for subscription"
        );

        if (subscriptionExpiration[msg.sender] > block.timestamp) {
            subscriptionExpiration[msg.sender] += subscriptionDuration;
        } else {
            subscriptionExpiration[msg.sender] =
                block.timestamp + subscriptionDuration;
        }
    }

    function isSubscriptionActive(address user) public view returns (bool) {
        return subscriptionExpiration[user] > block.timestamp;
    }

    function setSubscriptionPrice(uint256 newPrice) public {
        subscriptionPrice = newPrice;
    }

    function withdraw() public {
        payable(owner).transfer(address(this).balance);
    }
}

// 6. CommunityFunding
contract CommunityFunding {
    struct Project {
        uint256 id;
        string description;
        uint256 goalAmount;
        address payable creator;
        uint256 votes;
        bool isFunded;
    }

    Project[] public projects;
    mapping(uint256 => mapping(address => bool)) public hasVotedForProject;

    function createProject(string memory description, uint256 goalAmount ) public {
        require(goalAmount > 0, "Goal must be greater than zero");

        projects.push(
            Project({
                id: projects.length,
                description: description,
                goalAmount: goalAmount,
                creator: payable(msg.sender),
                votes: 0,
                isFunded: false
            })
        );
    }

    function voteForProject(uint256 projectId) public {
        require(projectId < projects.length, "Project does not exist");
        require(
            !hasVotedForProject[projectId][msg.sender],
            "Already voted for this project"
        );

        hasVotedForProject[projectId][msg.sender] = true;
        projects[projectId].votes += 1;
    }

    function releaseFunds(uint256 projectId) public {
        require(projectId < projects.length, "Project does not exist");
        Project storage project = projects[projectId];

        require(!project.isFunded, "Project already funded");
        require(project.votes >= 5, "Not enough votes to release funds");
        require(
            address(this).balance >= project.goalAmount,
            "Not enough funds in pool"
        );

        project.isFunded = true;
        project.creator.transfer(project.goalAmount);
    }

    function getAllProjects() public view returns (Project[] memory) {
        return projects;
    }
}
