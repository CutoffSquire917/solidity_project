const {ethers} = require("hardhat");

const deploy = async()=>{
    const factory = await ethers.getContractFactory("Market");
    const contract = await factory.deploy();

    await contract.waitForDeployment();

    console.log("Contract address: ", await contract.getAddress());
}

deploy().catch((error)=>{
    console.error(error);
    process.exitCode = -1;
})