public with sharing class BLDRNR_LogACaseController{
	
	public Case newCase {get;set;}
	public Contact currentCon {get;set;}
	
	public BLDRNR_LogACaseController(){
		newCase = new Case(ownerid='00G80000002RYCi');
		getCurrentCon();
	}
	
	public void getCurrentCon(){
		currentCon = [select id, firstName, lastName from Contact where User__c = :userInfo.getUserId()];
		newCase.ContactId = currentCon.id;
	}
	
	public PageReference submitCase(){
		insert newCase;
		PageReference ref = new PageReference('/'+newCase.id);
		return ref;
	}
	

}