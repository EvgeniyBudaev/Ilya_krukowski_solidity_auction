//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Голандский аукцион
contract AucEngine {
    address public owner; // владелец площадки
    uint constant DURATION = 2 days; // длительность аукциона // days конвертируется в секунды
    uint constant FEE = 10; // 10% комиссия выплачиваемая владельцу площадки
    struct Auction {
        address payable seller; //  человек который продает
        uint startingPrice; // максимальная цена продажи
        uint finalPrice; // Цена за которую купили товар
        uint startAt; // Время начала аукциона
        uint endsAt; // Время окончания аукциона
        uint discountRate; // Сколько мы будем сбрасывать каждую секунду от цены
        string item; // описание предмета
        bool stopped; // Закончился аукцион или нет?
    }

    Auction[] public auctions;

    event AuctionCreated(uint index, string itemName, uint startingPrice, uint duration);
    // Создаем событие что аукцион закончился
    event AuctionEnded(uint index, uint finalPrice, address winner);

    constructor() {
        owner = msg.sender; // Человек который развернул смарт-контракт будет являться владельцем
    }

    // Любой человек может создать аукцион
    // calldata неизменямое временное хранилище в памяти
    function createAuction(uint _startingPrice, uint _discountRate,string calldata _item, uint _duration) external {
        uint duration =_duration == 0 ? DURATION : _duration;
        require(_startingPrice >= _discountRate * duration, "incorrect starting price.");

        Auction memory newAuction = Auction({
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            finalPrice: _startingPrice,
            discountRate: _discountRate,
            startAt: block.timestamp,
            endsAt: block.timestamp + duration,
            item: _item,
            stopped: false
        });

        auctions.push(newAuction);

        emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration);
    }

    // Брать цену для аукциона на текущий момент времени
    function getPriceFor(uint index) public view returns(uint) {
        Auction memory cAuction = auctions[index];
        require(!cAuction.stopped, "stopped auction.");
        uint elapsed = block.timestamp - cAuction.startAt; // сколько времени прошло с начала аукциона
        uint discount = cAuction.discountRate * elapsed; // скидка с учетом времени
        return cAuction.startingPrice - discount;
    }

    function buy(uint index) external payable {
        Auction storage cAuction = auctions[index];
        require(!cAuction.stopped, "stopped auction.");
        require(block.timestamp < cAuction.endsAt, "auction ended.");
        uint cPrice = getPriceFor(index);
        require(msg.value >= cPrice, "not enough funds.");
        cAuction.stopped = true;
        cAuction.finalPrice = cPrice;
        // Вернем излишне перечисленные деньги
        uint refund = msg.value - cPrice;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
        // Подавцу товара перечислим деньги с учетом комиссии площадки
        cAuction.seller.transfer(
            cPrice - ((cPrice * FEE) / 100)
        );
        // Создаем событие в журнале событий блокчейна что аукцион закончился
        emit AuctionEnded(index, cPrice, msg.sender);
    }
}
