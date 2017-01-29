pragma solidity ^0.4.0;

contract fsmp {
    
// this contract constructor is for testing purpose    
/*  function fsmp() payable {
     createBuyOrder(100, 5);
     createStorageContract(0,1,1,"xxx.xxx.xxx.xxx:xxxxx"); 
     openStorageContract(0,1);
  }*/    
    
  struct SellOrder{
	uint id; //Sell Order Id (auto increment)
	address	DSO; //Data Storage Owner address of the contract
	uint volumeGB; //Volume of disk space, which DSO is ready to sell.
	uint pricePerGB; //	Min price in wei DSO ready to get for 1 second (will be 1 day in real case) per 1 GB storage
	string IPAndPort;//IP and port of Data Storage Owner
  }

  struct BuyOrder{
    uint id; //	Buy Order Id (auto increment)
    address DO;	//Data Owner address of the contract
    uint volumeGB;	//Volume of disk space, which DO is ready to buy.
    uint pricePerGB;	//Max price in wei DO ready to pay for 1 second (will be 1 day in real case) per 1 GB storage
    uint weiInitialAmount; // Quantity of wei, that is put into SmartContract at 
                           // the moment of Buy Order creation. 
                           // So it represent real value, that Escrow logic currently manage 
                           // (and real DO intention to pay for future Storage Contract)
  }
  
  struct StorageContract{
    uint id; //ContractID (auto increment)
    address DO; //Data owner address of the contract
    address DSO; //Data storage owner address
    string IPAndPort; //IP/port of data storage owner
    uint volumeGB; //Volume of disk space, which can be provided by DSO.
    uint openDate; //Date and time, which, if exists, indicates that the contract has been started
    uint closeDate;	//Date and time, which, if exists, indicates that the contract has been closed
    uint pricePerGB; //Price in wei to pay for 1 second (will be 1 day in real case) per 1 GB storage
    uint weiLeftToWithdraw;	//Quantity of wei, that can we withdrawed by DSO
    uint withdrawedAtDate; //Last date and time when wei was withdrawed by DSO
  }
  
  
  uint sellOrderId; // auto increment unique id
  uint buyOrderId; // auto increment unique id
  uint storageContractId; // auto increment unique id
  
  uint public sellOrderCount; // real quantity
  uint public buyOrderCount; // real quantity
  uint public storageContractCount; // real quantity

  SellOrder[] sellOrderArr; // array of sell orders
  BuyOrder[]  buyOrderArr; // array of buy orders
  StorageContract[]  storageContractArr; // array of contracts


  //################## Shared function ################################################
  
  function deleteBuyOrderFromArray (uint buyOrderIndex) internal {
    //if index not last element in the array
    if(buyOrderIndex != buyOrderArr.length-1){
        buyOrderArr[buyOrderIndex] = buyOrderArr[buyOrderArr.length-1];
    }
    buyOrderArr.length--;
    buyOrderCount--;
  }
  
  function deleteSellOrderFromArray (uint sellOrderIndex) internal {
    //if index not last element in the array
    if(sellOrderIndex != sellOrderArr.length-1){
        sellOrderArr[sellOrderIndex] = sellOrderArr[sellOrderArr.length-1];
    }
    sellOrderArr.length--;
    sellOrderCount--;
  }  
  
  function weiAllowedToWithdraw(uint storageContractIndex) constant returns (uint weiAllowedToWithdraw) {
      var c = storageContractArr[storageContractIndex];
      if (c.withdrawedAtDate == 0) return 0;
      weiAllowedToWithdraw = (now - c.withdrawedAtDate) * c.pricePerGB * c.volumeGB;
      return weiAllowedToWithdraw;
  }  
  
  //################## Trading ##########################################################
 
  function createBuyOrder(uint volumeGB, uint pricePerGB) payable {
      buyOrderArr.push(BuyOrder(++buyOrderId, msg.sender, volumeGB, pricePerGB, msg.value));
      buyOrderCount++;
  }
  
  function createSellOrder(uint volumeGB, uint pricePerGB, string IPAndPort) {
     sellOrderArr.push(SellOrder(++sellOrderId, msg.sender, volumeGB, pricePerGB, IPAndPort));
     sellOrderCount++;
  }
     
  // ############################################################################
  
    function createStorageContract(uint orderIndex, uint orderID, uint orderType, string IPAndPort) payable returns (uint newStorageContractID){

      //DSO calls the contract, orderType = "buy"
      if (orderType == 1) {
          
        //check if Buy Order id is equal to expected to avoid working with wrong or deleted Buy Order
        if (buyOrderArr[orderIndex].id != orderID) {
            throw;
        }
        
        storageContractArr.push(StorageContract(
            ++storageContractId,                //ContractID - auto increment
            buyOrderArr[orderIndex].DO,         //DO - from the BuyOrder data
            msg.sender,                         //DSO - from msg.sender (the function caller address)
            IPAndPort,                          //IPAndPort - from input IPAndPort param
            buyOrderArr[orderIndex].volumeGB,   //VolumeGB - from the BuyOrder data
            0,                                  //OpenDate - empty
            0,                                  //CloseDate - empty
            buyOrderArr[orderIndex].pricePerGB, //PricePerGB - from the BuyOrder data
            buyOrderArr[orderIndex].weiInitialAmount,   //WeiLeftToWithdraw - from the BuyOrder data
            0                                   //WeiWithdrawedAtDate - empty            
            ));
            
        storageContractCount++;
        deleteBuyOrderFromArray(orderIndex);
        return storageContractId;
        
      //DO call the contract, orderType = "sell"
      } else if (orderType == 2){
          
        //check if Sell Order Id is equal to expected to avoid working with wrong or deleted Sell Order
        if (sellOrderArr[orderIndex].id != orderID) {
            throw;
        }
        
        storageContractArr.push(StorageContract(
            ++storageContractId,                    //ContractID - auto increment
            msg.sender,                             //DO - from msg.sender (the function caller address)
            sellOrderArr[orderIndex].DSO,           //DSO - from the SellOrder data
            sellOrderArr[orderIndex].IPAndPort,    //IPAndPort - from the SellOrder data
            sellOrderArr[orderIndex].volumeGB,    //VolumeGB - from the SellOrder data
            0,                                      //OpenDate - empty
            0,                                      //CloseDate - empty
            sellOrderArr[orderIndex].pricePerGB,   //PricePerGB - from the SellOrder data
            msg.value,                              //WeiLeftToWithdraw - from msg.value (weis sent with the call)
            0                                       //WeiWithdrawedAtDate - empty
            ));
            
        storageContractCount++;
        deleteSellOrderFromArray(orderIndex);
        return storageContractId;
      }
      
      throw;
  }
  
  function refillStorageContract(uint storageContractIndex, uint storageContractID) payable {
      //TODO: add DO check and index - id check
      var c = storageContractArr[storageContractIndex];
      c.weiLeftToWithdraw += msg.value;
  }
  
  function withdrawFromStorageContract(uint storageContractIndex, uint storageContractID) returns(uint withdrawedWei) {
      //TODO: add DSO check, index - id check, open/close check, enough money check
      uint watw = this.weiAllowedToWithdraw(storageContractIndex);
      var c = storageContractArr[storageContractIndex];
      c.weiLeftToWithdraw -= watw;
      c.withdrawedAtDate = now;
      if (!msg.sender.send(watw)) throw;

      return watw;
  }
  
  function openStorageContract(uint storageContractIndex, uint storageContractID) {
      //TODO: add DO check and index - id check
      storageContractArr[storageContractIndex].openDate = now;
      storageContractArr[storageContractIndex].withdrawedAtDate = now;
  }
  
  function closeStorageContract(uint storageContractIndex, uint storageContractID) {
      //TODO: add DO/DSO check and index - id check
      storageContractArr[storageContractIndex].closeDate = now;
  }
  
  //
  
  function cancelBuyOrder(uint buyOrderIndex, uint buyOrderID){
      
      
       //throw an exception if index bigger then array
      if (buyOrderIndex >= buyOrderArr.length) throw;

      //check if user can cancel an order
      if(buyOrderArr[buyOrderIndex].DO == msg.sender && buyOrderArr[buyOrderIndex].id == buyOrderID){
         
         
            uint amount = buyOrderArr[buyOrderIndex].weiInitialAmount;
        
            if (msg.sender.send(amount)) {
                
                delete buyOrderArr[buyOrderIndex];
                
                //if index not last element in the array
                if(buyOrderIndex != buyOrderArr.length-1){
                    buyOrderArr[buyOrderIndex] = buyOrderArr[buyOrderArr.length-1];
                    delete buyOrderArr[buyOrderArr.length-1];
                }
                
                buyOrderArr.length--;
                
                return;
            } else {
                
                throw;
            }
          
      }else{
          throw;
      }
      
  }
  
  function cancelSellOrder(uint sellOrderIndex, uint sellOrderID){
      
      //throw an exception if index bigger then array
      if (sellOrderIndex >= sellOrderArr.length) throw;
      
      //check if user can cancel an order
      if(sellOrderArr[sellOrderIndex].DSO == msg.sender && sellOrderArr[sellOrderIndex].id == sellOrderID){
          
          delete sellOrderArr[sellOrderIndex];
          
          //if index not last element in the array
           if(sellOrderIndex != sellOrderArr.length-1){
                sellOrderArr[sellOrderIndex] = sellOrderArr[sellOrderArr.length-1];
                delete sellOrderArr[sellOrderArr.length-1];
            }
            
            sellOrderArr.length--;
          
          return;
      }else{
          throw;
      }
      
  }
  
  
  
  //Utility functions - constant
  
  //Buy order
  //function getBuyOrder(uint buyOrderIndex, uint buyOrderID)constant returns(uint id,address DO,uint volume,uint pricePerGB,uint weiInitialAmount){
  function getBuyOrder(uint buyOrderIndex)constant returns(uint id,address DO,uint volume,uint pricePerGB,uint weiInitialAmount){
      return (buyOrderArr[buyOrderIndex].id,
              buyOrderArr[buyOrderIndex].DO,
              buyOrderArr[buyOrderIndex].volumeGB,
              buyOrderArr[buyOrderIndex].pricePerGB,
              buyOrderArr[buyOrderIndex].weiInitialAmount);
  }
  
  function buyOrdersLength() constant returns(uint) {
      return buyOrderArr.length;
  }

  //Sell order    
  //function getSellOrder(uint sellOrderIndex, uint sellOrderID)constant returns(uint id,address DSO,uint volume,uint pricePerGB,string IPAndPort) {
    function getSellOrder(uint sellOrderIndex)constant returns(uint id,address DSO,uint volume,uint pricePerGB,string IPAndPort) {
      return (sellOrderArr[sellOrderIndex].id,
              sellOrderArr[sellOrderIndex].DSO,
              sellOrderArr[sellOrderIndex].volumeGB,
              sellOrderArr[sellOrderIndex].pricePerGB,
              sellOrderArr[sellOrderIndex].IPAndPort);
  }  
  
  function sellOrdersLength() constant returns(uint){
    return sellOrderArr.length;
  }
  
  //Storage Contract
  
  function getStorageContract(uint storageContractIndex) constant returns(
        uint id,
        address DO, 
        address DSO, 
        string IPandPort, 
        uint volumeGB, 
        uint openDate, 
        uint closeDate, 
        uint pricePerGB, 
        uint weiLeftToWithdraw, 
        uint withdrawedAtDate, 
        uint weiAllowedToWithdraw
    ) {
        
      var contr = storageContractArr[storageContractIndex];
      uint watw = this.weiAllowedToWithdraw(storageContractIndex);
        
      return (contr.id,
              contr.DO,
              contr.DSO,
              contr.IPAndPort,
              contr.volumeGB,
              contr.openDate,
              contr.closeDate,
              contr.pricePerGB,
              contr.weiLeftToWithdraw,
              contr.withdrawedAtDate,
              watw
              );
  }
  
  function storageContractsLength() constant returns(uint){
      return storageContractArr.length;
  }
}