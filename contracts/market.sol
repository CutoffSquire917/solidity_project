// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Market {
    struct Product {
        string name;
        string description;
        uint256 price;
        address creator;
        uint256 createdAt;
        string imageUrl;
    }

    Product[] private products;

    event ProductCreated(uint256 indexed id, address indexed creator, string name, uint256 price);

    function createProduct(
        string calldata name,
        string calldata description,
        uint256 price,
        string calldata imageUrl
    ) external {
        require(bytes(name).length > 0, "Name is required");
        require(bytes(name).length <= 100, "Name is too long");
        require(bytes(description).length <= 1000, "Description is too long");
        require(bytes(imageUrl).length <= 500, "Image URL is too long");

        products.push(Product(name, description, price, msg.sender, block.timestamp, imageUrl));
        emit ProductCreated(products.length - 1, msg.sender, name, price);
    }

    function getProducts() external view returns (Product[] memory) {
        return products;
    }

    function getProduct(uint256 id) external view returns (Product memory) {
        require(id < products.length, "Product does not exist");
        return products[id];
    }

    function productsCount() external view returns (uint256) {
        return products.length;
    }
}
