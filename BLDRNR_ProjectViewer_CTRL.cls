global with sharing class BLDRNR_ProjectViewer_CTRL {

    global BLDRNR_ProjectViewer_CTRL(ApexPages.StandardController controller){}  

    @RemoteAction
    global static list<Node> getProjects(string cid) {
        list<Node> returnList = new list<Node>();
        list<TASKRAY__Project__c> projectList = new list<TASKRAY__Project__c>();
        
        //base node        
        Node basenode = new Node();
        basenode.ProjectName = 'TOP LEVEL PROJECTS';         
        basenode.id = '';        
        basenode.ProjectColor = '#787878';
        returnList.add(basenode);
        
        if (cid != '')
            projectList = [select t.id, t.TASKRAY__Status__c, t.TASKRAY__Project_Start__c, t.TASKRAY__Project_End__c, t.TASKRAY__ProjectColor__c, t.Name From TASKRAY__Project__c t where TASKRAY__Project_Parent__c = :cid];
        else
            projectList = [select t.id, t.TASKRAY__Status__c, t.TASKRAY__Project_Start__c, t.TASKRAY__Project_End__c, t.TASKRAY__ProjectColor__c, t.Name From TASKRAY__Project__c t where TASKRAY__Project_Parent__c = null];


        for (TASKRAY__Project__c t : projectList){
            Node n = new Node();
            n.ProjectName = t.Name;
            n.id = t.Id;            
            n.StartDate = string.valueOf(t.TASKRAY__Project_Start__c);
            n.EndDate = string.valueOf(t.TASKRAY__Project_End__c);
            n.link =  URL.getSalesforceBaseUrl().toExternalForm() + '/' + t.Id;
            n.ParentProject = '';
            n.ProjectColor = t.TASKRAY__ProjectColor__c;
            n.isTask = false;
            returnList.add(n);            
        }
        
        //if we only have the base node, remove it and return an empty set
        if (returnList.size() == 1)
            returnList.remove(0);
        
        return returnList;
    }

    @RemoteAction
    global static list<Node> getProjectTasks(string cid){
        List<Node> returnList = new List<Node>();
        List<TASKRAY__Project_Task__c> ptList = new List<TASKRAY__Project_Task__c>();
        
        system.debug('CID IS FOR PROJECT TASKS: ' + cid);
        id myid = (id)cid;
        ptList = [select id, Name, TASKRAY__Deadline__c, TASKRAY__Project__r.TASKRAY__ProjectColor__c from TASKRAY__Project_Task__c where TASKRAY__Project__c = :myid];
        
        for (TASKRAY__Project_Task__c tpt : ptList){
            Node n = new Node();
            n.id = tpt.Id;
            n.ProjectName = tpt.Name;
            n.StartDate = string.ValueOf(tpt.TASKRAY__Deadline__c);
            n.EndDate = string.ValueOf(tpt.TASKRAY__Deadline__c);
            n.link = URL.getSalesforceBaseUrl().toExternalForm() + '/' + tpt.Id;
            n.ProjectColor = tpt.TASKRAY__Project__r.TASKRAY__ProjectColor__c;	
        	n.ParentProject = tpt.TASKRAY__Project__c;
        	n.isTask = true;
        	returnList.add(n);
        }       
        
        system.debug('RETURNLIST SIZE IS: ' + returnList.size());
    	return returnList;
    }


    global class Node { 
        string ProjectName;
        string StartDate;
        string id;
        string EndDate;
        string link;
        string ParentProject;
        string ProjectColor;
        boolean isTask;
    }  
    
    static testMethod void Test_BLDRNR_ProjectViewer_CTRL(){
        
        List<BLDRNR_ProjectViewer_CTRL.Node> nlist = new list<BLDRNR_ProjectViewer_CTRL.Node>();    	
    	 
        TASKRAY__Project__c tp = new TASKRAY__Project__c(
                Name = 'TR Project',
                TASKRAY__Project_Start__c = system.today(),
                TASKRAY__Project_End__c = system.today().addDays(1)        
            );        
        insert tp;        
        
        TASKRAY__Project__c tp2 = new TASKRAY__Project__c(
                Name = 'TR Project',
                TASKRAY__Project_Start__c = system.today(),
                TASKRAY__Project_End__c = system.today().addDays(1),
                TASKRAY__Project_Parent__c = tp.id        
            );        
        insert tp2;        
        
        TASKRAY__Project_Task__c tpt = new TASKRAY__Project_Task__c(
                TASKRAY__Project__c = tp2.Id,
                TASKRAY__List__c = 'Holding',
                TASKRAY__Status__c = 'Not Yet Started',
                TASKRAY__Description__c = 'Old Description'
            );
        insert tpt;   
        
    	nlist = BLDRNR_ProjectViewer_CTRL.getProjects('');
    	system.assert(nlist.size() > 1);
    	nlist = BLDRNR_ProjectViewer_CTRL.getProjects((string)tp.id);
    	system.assert(nlist.size() > 1);
        nlist = BLDRNR_ProjectViewer_CTRL.getProjectTasks((string)tp2.id);
        system.assert(nlist.size() == 1);
    }
}