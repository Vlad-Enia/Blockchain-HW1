// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <=0.8.21;

contract ProductIdentification
{
    uint public tax;
    address admin;
    address[] producers;
    mapping (uint => Product) products;
    uint productId;

    event debug(uint);

    struct Product
    {
        address producer;
        string name;
        uint volume;
    }

    constructor()
    {
        tax = 5;
        admin = msg.sender;
        productId = 0;
    }

    modifier onlyAdmin()
    {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function setTax(uint _tax) onlyAdmin() public 
    {
        tax = _tax;
    }

    modifier taxReq()
    {
        require(msg.value >= tax, "You have to pay tax");
        _;
        if (msg.value > tax)
        {
            uint rest = msg.value - tax;
            payable(msg.sender).transfer(rest);
        }
    }

    function registerProducer() taxReq() payable external 
    {
        producers.push(msg.sender);
    }

    modifier registeredProducer()
    {
        require(isProducerRegistered(msg.sender), "Must be registered producer");
        _;
    }

    function registerProduct(string calldata _name, uint _volume) registeredProducer() external 
    {
        Product memory product = Product(msg.sender, _name, _volume);
        products[productId] = product;
        productId++;
    }

    function isProducerRegistered(address _address) view public returns (bool)
    {
        for (uint256 i=0; i < producers.length; i++)
        {
            if (producers[i] == _address)
                return true;
        }
        return false;
    }

    function getProduct(uint id) view public returns (Product memory)
    {
        return products[id];
    }

    function productExists(uint id) view public returns (bool)
    {
        return products[id].producer != address(0);
    }


    function getProductProducer(uint _productId) view public returns (address)
    {
        return products[_productId].producer;
    }
}

contract ProductDeposit
{
    uint public maxDeposit;
    uint public taxPerUnit;
    address admin;
    address productIdentification;
    mapping (uint => uint) deposits;
    mapping (address => address) stores;
    uint totalVolume;

    constructor()
    {
        taxPerUnit = 5;
        maxDeposit = 10;
        admin = msg.sender;
    }

    modifier onlyAdmin()
    {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function setProductIdentification(address _productIdentification) public 
    {
        productIdentification = _productIdentification;
    }

    function setTaxPerUnit(uint _tax) onlyAdmin() public 
    {
        taxPerUnit = _tax;
    }

    function setMaxDeposit(uint _max) onlyAdmin() public 
    {
        maxDeposit = _max;
    }

    modifier validDeposit(uint _productId, uint _quantity)
    {
        ProductIdentification aux = ProductIdentification(productIdentification);
        uint productVolume = aux.getProduct(_productId).volume;
        uint reqTax = _quantity * taxPerUnit;
        require(msg.value >= reqTax, "Insufficient tax");
        require(totalVolume + _quantity * productVolume <= maxDeposit, "Too much volume");
        require(aux.getProductProducer(_productId) == msg.sender, "Unauthorized producer");

        _;

        if (msg.value > reqTax)
        {
            uint rest = msg.value - reqTax;
            payable(msg.sender).transfer(rest);
        }
    }

    function depositProduct(uint _productId, uint _quantity) validDeposit(_productId, _quantity) payable external
    {
        ProductIdentification aux = ProductIdentification(productIdentification);
        uint productVolume = aux.getProduct(_productId).volume;
        deposits[_productId] += _quantity;
        totalVolume += _quantity * productVolume;
    }

    modifier validWithdraw(uint _productId, uint _quantity)
    {
        ProductIdentification aux = ProductIdentification(productIdentification);
        require(deposits[_productId] >= _quantity , "Insufficient volume");
        address productProducer = aux.getProductProducer(_productId);
        require(productProducer == msg.sender || stores[productProducer] == msg.sender, "Unauthorized");
        _;
    }

    function withdrawProduct(uint _productId, uint _quantity) validWithdraw(_productId, _quantity) external 
    {
        ProductIdentification aux = ProductIdentification(productIdentification);
        uint productVolume = aux.getProduct(_productId).volume;
        deposits[_productId] -= _quantity;
        totalVolume -= _quantity * productVolume;
    }

    function registerStore(address _store) external 
    {
        stores[msg.sender] = _store;
    }
}

contract ProductStore
{
    address admin;
    address depositAddress;
    address productIdentificationAddress;
    mapping (uint => uint) productsStocks;
    mapping (uint => uint) productsPrices;

    constructor()
    {
        admin=msg.sender;
    }

    modifier onlyAdmin()
    {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function setDepositAddress(address _depositAddress) onlyAdmin() public 
    {
        depositAddress = _depositAddress;
    }
    

    function setProductIdentificationAddress(address _productIdentificationAddress) onlyAdmin() public 
    {
        productIdentificationAddress = _productIdentificationAddress;
        ProductDeposit aux = ProductDeposit(depositAddress);
        aux.setProductIdentification(_productIdentificationAddress);
    }

    function supplyStore(uint _productId, uint _volume) onlyAdmin() public 
    {
        ProductDeposit aux = ProductDeposit(depositAddress);
        aux.withdrawProduct(_productId, _volume);
        productsStocks[_productId] += _volume;
    }

    function setPrice(uint _productId, uint _price) onlyAdmin() public 
    {
        productsPrices[_productId] = _price;
    }

    function verifyProduct(uint _productId) public view returns (bool)
    {
        if (productsStocks[_productId] == 0)
        {
            return false;
        }
        ProductIdentification aux = ProductIdentification(productIdentificationAddress);
        return aux.productExists(_productId);
    }

    modifier validBuy(uint _productId, uint _volume)
    {
        require(productsStocks[_productId] >= _volume, "Insufficient volume");
        uint price = productsPrices[_productId] * _volume;
        require(msg.value >= price,"Insufficient funds");

        _;


        if (msg.value > price)
        {
            uint rest = msg.value - price;
            payable(msg.sender).transfer(rest);
        }
    }

    function buyProduct(uint _productId,uint _volume) validBuy(_productId, _volume) public payable
    {
        productsStocks[_productId] -= _volume;
        uint price = productsPrices[_productId] * _volume;

        ProductIdentification aux = ProductIdentification(productIdentificationAddress);
        address productProducer =  aux.getProductProducer(_productId);
        payable(productProducer).transfer(price/2);
    }
    

}