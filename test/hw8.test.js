const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GrandmaGifts", () => {
    const DAY = 24 * 60 * 60;
    const TOTAL = ethers.parseEther("3");
    const GIFT = ethers.parseEther("1");

    const deploy = async () => {
        const [grandma, child1, child2, child3, stranger] = await ethers.getSigners();

        const now = await time.latest();
        const birthdays = [now + 10 * DAY, now + 20 * DAY, now + 30 * DAY];
        const wallets = [child1.address, child2.address, child3.address];

        const factory = await ethers.getContractFactory("GrandmaGifts", grandma);
        const c_gifts = await factory.deploy(wallets, birthdays);
        await c_gifts.waitForDeployment();

        return { c_gifts, grandma, child1, child2, child3, stranger, birthdays, wallets };
    };

    const deployFunded = async () => {
        const ctx = await deploy();
        await ctx.c_gifts.connect(ctx.grandma).deposit({ value: TOTAL });
        return ctx;
    };

    describe("Deployment and deposit", () => {
        it("Grandma deploys the contract and registers grandchildren with birthdays", async () => {
            const { c_gifts, grandma, wallets, birthdays } = await loadFixture(deploy);

            expect(await c_gifts.getAddress(), "Contract address isn't correct").to.be.properAddress;
            expect(await c_gifts.grandma(), "Grandma address is wrong").to.eq(grandma.address);
            expect(await c_gifts.grandchildrenCount(), "Grandchildren count is wrong").to.eq(3);
            expect(await c_gifts.funded(), "Contract must not be funded yet").to.eq(false);

            for (let i = 0; i < wallets.length; i++) {
                const g = await c_gifts.info(wallets[i]);
                expect(g.registered, "Grandchild must be registered").to.eq(true);
                expect(g.claimed, "Grandchild must not have claimed yet").to.eq(false);
                expect(g.birthday, "Birthday is wrong").to.eq(birthdays[i]);
            }
        });

        it("Grandma deposits funds", async () => {
            const { c_gifts, grandma } = await loadFixture(deploy);

            await expect(c_gifts.connect(grandma).deposit({ value: TOTAL }))
                .to.emit(c_gifts, "Deposited")
                .withArgs(grandma.address, TOTAL, GIFT, 0);

            expect(await c_gifts.funded(), "Contract must be funded").to.eq(true);
            expect(await ethers.provider.getBalance(c_gifts.target), "Contract balance is wrong").to.eq(TOTAL);
        });

        it("Rejects invalid constructor arguments", async () => {
            const [grandma, child1, child2] = await ethers.getSigners();
            const factory = await ethers.getContractFactory("GrandmaGifts", grandma);

            await expect(factory.deploy([], [])).to.be.revertedWith("No grandchildren");
            await expect(factory.deploy([child1.address, child2.address], [1])).to.be.revertedWith("Length mismatch");
            await expect(factory.deploy([child1.address, child1.address], [1, 2])).to.be.revertedWith("Duplicate grandchild");
            await expect(factory.deploy([ethers.ZeroAddress], [1])).to.be.revertedWith("Zero address");
        });

        it("Rejects deposit from a non-grandma, second deposit and too small deposit", async () => {
            const { c_gifts, grandma, stranger } = await loadFixture(deploy);

            await expect(c_gifts.connect(stranger).deposit({ value: TOTAL })).to.be.revertedWith("Only grandma");
            await expect(c_gifts.connect(grandma).deposit({ value: 2 })).to.be.revertedWith("Deposit too small");

            await c_gifts.connect(grandma).deposit({ value: TOTAL });
            await expect(c_gifts.connect(grandma).deposit({ value: TOTAL })).to.be.revertedWith("Already funded");
        });
    });

    describe("Gift amount", () => {
        it("Splits the deposit equally between grandchildren", async () => {
            const { c_gifts } = await loadFixture(deployFunded);

            expect(await c_gifts.giftAmount(), "Gift amount must be total / count").to.eq(TOTAL / 3n);
        });

        it("Refunds the division remainder to grandma", async () => {
            const { c_gifts, grandma } = await loadFixture(deploy);

            await expect(c_gifts.connect(grandma).deposit({ value: 10 }))
                .to.emit(c_gifts, "Deposited")
                .withArgs(grandma.address, 10, 3, 1);

            expect(await c_gifts.giftAmount(), "Gift amount is wrong").to.eq(3);
            expect(await ethers.provider.getBalance(c_gifts.target), "Contract must keep only gifts").to.eq(9);
        });
    });

    describe("Claiming", () => {
        it("Grandchild claims the gift on the birthday", async () => {
            const { c_gifts, child1, birthdays } = await loadFixture(deployFunded);

            await time.setNextBlockTimestamp(birthdays[0]);

            await expect(c_gifts.connect(child1).claim()).to.changeEtherBalances(
                [child1, c_gifts],
                [GIFT, -GIFT]
            );

            expect((await c_gifts.info(child1.address)).claimed, "Gift must be marked as claimed").to.eq(true);
        });

        it("Grandchild claims the gift after the birthday", async () => {
            const { c_gifts, child2, birthdays } = await loadFixture(deployFunded);

            await time.increaseTo(birthdays[1] + 7 * DAY);

            await expect(c_gifts.connect(child2).claim()).to.changeEtherBalances(
                [child2, c_gifts],
                [GIFT, -GIFT]
            );

            expect((await c_gifts.info(child2.address)).claimed, "Gift must be marked as claimed").to.eq(true);
        });

        it("Rejects claiming before the birthday", async () => {
            const { c_gifts, child1 } = await loadFixture(deployFunded);

            await expect(c_gifts.connect(child1).claim()).to.be.revertedWith("Birthday has not come yet");
            expect(await ethers.provider.getBalance(c_gifts.target), "Contract balance must not change").to.eq(TOTAL);
        });

        it("Rejects claiming twice", async () => {
            const { c_gifts, child1, birthdays } = await loadFixture(deployFunded);

            await time.increaseTo(birthdays[0] + DAY);
            await c_gifts.connect(child1).claim();

            await expect(c_gifts.connect(child1).claim()).to.be.revertedWith("Already claimed");
            expect(await ethers.provider.getBalance(c_gifts.target), "Only one gift must be paid").to.eq(TOTAL - GIFT);
        });

        it("Rejects claiming by a stranger", async () => {
            const { c_gifts, stranger, birthdays } = await loadFixture(deployFunded);

            await time.increaseTo(birthdays[2] + DAY);

            await expect(c_gifts.connect(stranger).claim()).to.be.revertedWith("Not a grandchild");
        });

        it("Rejects claiming before the contract is funded", async () => {
            const { c_gifts, child1, birthdays } = await loadFixture(deploy);

            await time.increaseTo(birthdays[0] + DAY);

            await expect(c_gifts.connect(child1).claim()).to.be.revertedWith("Not funded yet");
        });

        it("Every grandchild can claim and the contract ends up empty", async () => {
            const { c_gifts, child1, child2, child3, birthdays } = await loadFixture(deployFunded);

            await time.increaseTo(birthdays[2] + DAY);

            await c_gifts.connect(child1).claim();
            await c_gifts.connect(child2).claim();
            await c_gifts.connect(child3).claim();

            expect(await ethers.provider.getBalance(c_gifts.target), "Contract balance must be: 0 ETH").to.eq(0);
        });
    });

    describe("Events", () => {
        it("Emits GiftClaimed with the grandchild address and the amount", async () => {
            const { c_gifts, child3, birthdays } = await loadFixture(deployFunded);

            await time.increaseTo(birthdays[2]);

            await expect(c_gifts.connect(child3).claim())
                .to.emit(c_gifts, "GiftClaimed")
                .withArgs(child3.address, GIFT);
        });
    });
});