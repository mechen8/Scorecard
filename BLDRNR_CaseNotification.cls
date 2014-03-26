/**
* @author Kevin Bromer
* @date 6/19/12
* @description Handles generation of Case Comments when values in a project or a project task change
*/
public with sharing class BLDRNR_CaseNotification {

    private static final String TRACKING_FIELD_SET = 'Field_Change_Notifications';      
    private static List<Schema.FieldSetMember> fields;
    private static List<CaseComment> commentsForInsert = new list<CaseComment>();
    private static List<FeedItem> feedComments = new list<FeedItem>(); 
    private static Map<Id, Case> caseMap;

    public static void doCaseNotification(Map<id, TASKRAY__Project__c> tpMapNew, Map<id, TASKRAY__Project__c> tpMapOld){
    	fields = Schema.SObjectType.TASKRAY__Project__c.fieldSets.getMap().get(TRACKING_FIELD_SET).getFields();
        
        caseMap = new Map<Id, Case>([select id, Project__c, Project_Task__c from Case where Project__c IN :tpMapNew.keySet()]);
        
        if (!caseMap.isEmpty())
            generateUpdateComment((Map<id, sobject>)tpMapNew, (Map<id, sobject>)tpMapOld);        
    }  
    
    public static void doCaseNotification(Map<id, TASKRAY__Project_Task__c> tptMapNew, Map<id, TASKRAY__Project_Task__c> tptMapOld){
    	fields = Schema.SObjectType.TASKRAY__Project_Task__c.fieldSets.getMap().get(TRACKING_FIELD_SET).getFields();
    	List<id> ProjIDList = new List<id>();
    	//create a list of all project Ids
    	for (TASKRAY__Project_Task__c tskry : tptMapNew.values()){
    		ProjIDList.add(tskry.TASKRAY__Project__c);
    	}    	
        
        caseMap = new Map<Id, Case>([select id, Project__c, Project_Task__c from Case where Project_Task__c IN :tptMapNew.keySet() OR Project__c IN :ProjIDList]);        
            
        if (!caseMap.isEmpty())            
            generateUpdateComment((Map<id, sobject>)tptMapNew, (Map<id, sobject>)tptMapOld);
    }
    
    private static void generateUpdateComment(Map<id, sobject> newMap, Map<id, sobject> oldMap){
        
        for (sobject obj : newMap.values()){ 
        	//determine if we even need to update this
            Set<String> updatedFields = new Set<string>();
            for (Schema.FieldSetMember fsm : fields){
            	if ((object)obj.get(fsm.getFieldPath()) != (object)oldMap.get(obj.id).get(fsm.getFieldPath())){
                    updatedFields.add(fsm.getFieldPath());            		
            	}            	
            }
            
            if (updatedFields.size() > 0){
            	for (Case c : caseMap.values()){
                    
                    //if its a task, we need to get teh associated project 
                    id pid;
                    boolean isTask = false;
                    if (obj instanceof TASKRAY__Project_Task__c){
                    	pid = (id)obj.get('TASKRAY__Project__c');
                    	isTask = true;
                    }
             
                    if (obj.id == c.Project__c || obj.id == c.Project_Task__c || (pid != null && pid == c.Project__c)){                    
                        CaseComment cc = new CaseComment();
                        cc.IsPublished = true;
                        cc.ParentId = c.id;
                        
                        String cComment = '';
                        String feedBody = '';
                        
                        if (isTask)
                            cComment += ' ' + system.Label.BLDRNR_TaskUpdateText + '\n';
                        else                            
                            cComment += ' ' + system.Label.BLDRNR_ProjectUpdateText + '\n';
                            
                        for (Schema.FieldSetMember fsm : fields){
                            if (updatedFields.contains(fsm.getFieldPath())){
                                cComment += fsm.getLabel() + ' ' + system.Label.BLDRNR_FieldChangeText + ' ';
                                cComment += '"' + String.valueOf(obj.get(fsm.getFieldPath())) + '"\n';
                            }                                
                    	}
                        
                        feedBody = cComment; 
                        cComment = system.Label.BLDRNR_UpdateCommentText + ' ' + cComment;                        
                        cc.CommentBody = cComment;                        
                        commentsForInsert.add(cc);
                        
                        FeedItem cf = new FeedItem(                            
                            ParentId = c.id,                            
                            Body = feedBody
                        );                        
                        feedComments.add(cf);                         
                    }                    
                }
            }                            
        }    
    
        if (!commentsForInsert.isEmpty()){
        	insertComments(commentsForInsert);
        }
        if (!feedComments.isEmpty()){
        	insertFeedItems(feedComments);
        }    
    }
    
    private static void insertFeedItems(List<FeedItem> fList){
    	insert fList;
    }

    private static void insertComments(List<CaseComment> iList){
    	insert iList;
    }
}