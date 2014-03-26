/**
* @author Kevin Bromer
* @date 6/19/12
* @description Task class for Case notifications for BladeRunner setup
*/     
@isTest    
public with sharing class BLDRNR_CaseNotification_TEST{

    private static TASKRAY__Project__c tp;
    private static TASKRAY__Project_Task__c tpt;     
    private static Case c;     
    private static final Id TechTeamReqId = [select id from RecordType where sobjecttype = 'Case' and Name = 'Tech Request' limit 1].id;
    
    static testMethod void testTaskUpdate(){ 
        setupTestData();
        
        String testText = 'Description now changed';
        
        test.startTest();        
        tpt.TASKRAY__Description__c = testText;
        update tpt;        
        test.stopTest();
                 	
        String feedbody = [select Body from FeedItem where ParentId = :c.id order by CreatedDate desc limit 1].Body;            	
    	system.assert(feedbody.contains(testText));
    	
    	String ccbody = [select Commentbody from CaseComment where ParentId = :c.id limit 1].Commentbody;
    	system.assert(ccbody.contains(testText));           	
    }
    
    static testMethod void testProjectUpdate(){  
        setupTestData();
          
        test.startTest();        
        tp.TASKRAY__Project_End__c = system.today().addDays(2);
        update tp;        
        test.stopTest();
        
        String compareString = string.valueOf(system.today().addDays(2));
                
        String feedbody = [select Body from FeedItem where ParentId = :c.id order by CreatedDate desc limit 1].Body;                
        system.assert(feedbody.contains(compareString));
        
        String ccbody = [select Commentbody from CaseComment where ParentId = :c.id limit 1].Commentbody;
        system.assert(ccbody.contains(compareString));    
    }    
    
    private static void setupTestData(){     
              
        if (tp == null){
        	tp = new TASKRAY__Project__c(
                Name = 'TR Project',
                TASKRAY__Project_Start__c = system.today(),
                TASKRAY__Project_End__c = system.today().addDays(1)        
            );        
            insert tp;
        }    
        
        if (tpt == null){                    
            tpt = new TASKRAY__Project_Task__c(
                TASKRAY__Project__c = tp.Id,
                TASKRAY__List__c = 'Holding',
                TASKRAY__Status__c = 'Not Yet Started',
                TASKRAY__Description__c = 'Old Description'
            );
            insert tpt;   
        }
        
        if (c == null){
            c = new Case(
                RecordtypeId = TechTeamReqId,
                Status = 'New',
                System__c = 'Website',
                Priority = '3 - Annoying/Has Workaround',
                Project__c = tp.id,
                Description = 'TestCase'
            );
            insert c;
        }
    }
}