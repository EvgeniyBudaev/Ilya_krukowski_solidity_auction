const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AucEngine", function () {
    let owner;
    let seller;
    let buyer;
    let auct;

    beforeEach(async function () {
        [owner, seller, buyer] = await ethers.getSigners();
        const AucEngine = await ethers.getContractFactory("AucEngine", owner);
        auct = await AucEngine.deploy();
        await auct.deployed();
    });

    // После развертывания контракта был установлен корректный владелец 
    it("sets owner", async function () {
        const currentOwner = await auct.owner();
        expect(currentOwner).to.eq(owner.address);
    });

    // bn - номер блокчейна
    async function getTimestamp(bn) {
        return (
            await ethers.provider.getBlock(bn)
        ).timestamp
    }

    describe("createAuction", function () {
        // Тестирование создания аукциона
        it("creates auction correctly", async function () {
            const duration = 60;
            const transaction = await auct.createAuction(
                ethers.utils.parseEther("0.0001"),
                3,
                "fake item",
                duration
            );

            const currentAuction = await auct.auctions(0);
            expect(currentAuction.item).to.eq("fake item");
            const ts = await getTimestamp(transaction.blockNumber);
            expect(currentAuction.endsAt).to.eq(ts + duration);
        });
    });

    function delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    describe("buy", function () {
        it("allows to buy", async function () {
            const transaction = await auct.connect(seller).createAuction(
                ethers.utils.parseEther("0.0001"),
                3,
                "fake item",
                60
            );

            this.timeout(5000);
            await delay(1000);

            const buyTransaction = await auct.connect(buyer).buy(0, { value: ethers.utils.parseEther("0.0001") });
            const currentAuction = await auct.auctions(0);
            const finalPrice = currentAuction.finalPrice;
            await expect(() => buyTransaction).to.changeEtherBalance(
                seller, finalPrice - Math.floor((finalPrice * 10) / 100)
            )

            // Проверяем было ли создано событие
            await expect(buyTransaction).to.emit(
                auct, "AuctionEnded").withArgs(0, finalPrice, buyer.address);

            // После того как покупак совершилась и аукцион остановился,
            // что нельзя еще раз купить тот же самый товар
            await expect(
                auct.connect(buyer)
                .buy(0, { value: ethers.utils.parseEther("0.0001") })
                ).to.be.revertedWith("Insufficient funds");
        });
    });
});
