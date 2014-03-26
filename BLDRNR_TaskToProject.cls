public with sharing class BLDRNR_TaskToProject {
	
	public static id taskID {get{
					if(ApexPages.CurrentPage().getParameters().get('id') != null){
						return ApexPages.CurrentPage().getParameters().get('id');
					} else{
						return null;
					}
					
				}}
	public TASKRAY__Project_Task__c oldtask {get;set;}

	public list<selectoption> projectList {get;set;}

	public TASKRAY__Project__c newProject {get;set;}

	public BLDRNR_TaskToProject() {
		getCurrentTask();
		createProject();
		getProjectList();
	}

	public void getCurrentTask(){
		oldtask = [select id, name, TASKRAY__Description__c, TASKRAY__Deadline__c, TASKRAY__Project__c, TASKRAY__Project__r.name from TASKRAY__Project_Task__c where id =:taskID];
	}

	public void createProject(){
		newProject = new TASKRAY__Project__c(
				name = oldtask.name,
				TASKRAY__Project_Parent__c = oldtask.TASKRAY__Project__c,
				Description__c = oldtask.TASKRAY__Description__c,
				TASKRAY__Project_End__c = oldTask.TASKRAY__Deadline__c,
				TASKRAY__Project_Start__c = Date.today()
			);
	}

	public void getProjectList(){
		projectList = new list<selectoption>();
		selectoption s1 = new selectoption(oldTask.TASKRAY__Project__c, oldTask.TASKRAY__Project__r.name);
		projectList.add(s1);
		selectoption s2 = new selectoption('', 'No Parent');
		projectList.add(s2);
		list<TASKRAY__Project__c> projects = [select id, name from TASKRAY__Project__c where TASKRAY__Status__c = false AND TASKRAY__Project_Parent__c = null ORDER BY Name ASC];
		for(TASKRAY__Project__c p :projects){
			if(p.id != oldTask.TASKRAY__Project__c){
				selectoption s = new selectoption(p.id, p.name);
				projectList.add(s);
			}
		}
	}

	public pageReference saveProject(){
		insert newProject;
		oldTask.name = oldTask.Name + ' - ARCHIVE - CONVERTED TO PROJECT';
		oldTask.TASKRAY__List__c = 'Completed';
		oldtask.TASKRAY__Project__c = newProject.id;
		update oldTask;
		pageReference pr = new pageReference('/apex/TASKRAY__trprojectboard?projectid='+newProject.id);
		return pr;
	}

	public pageReference cancel(){
		pageReference pr = new pageReference('/'+oldTask.id);
		return pr;
	}

	static testmethod void convertTaskTest(){
		TASKRAY__Project__c project = new TASKRAY__Project__c(
			Name = 'Project',
			TASKRAY__status__c = false
		);
		insert project;
		TASKRAY__Project_Task__c task1 = new TASKRAY__Project_Task__c(
			Name = 'Task 1',
			TASKRAY__Project__c = project.id,
			TASKRAY__List__c = 'Holding'
		);
		insert task1;

		System.currentPageReference().getParameters().put('id', task1.id);
		BLDRNR_TaskToProject controller = new BLDRNR_TaskToProject();
		controller.saveProject();
		system.assertEquals(controller.newProject.name, 'Task 1');
		system.assertEquals(controller.oldTask.name, 'Task 1 - ARCHIVE - CONVERTED TO PROJECT');
		system.assertEquals(controller.oldTask.TASKRAY__Project__c, controller.newProject.id);

	}

	static testmethod void convertTaskCancelTest(){
		TASKRAY__Project__c project = new TASKRAY__Project__c(
			Name = 'Project',
			TASKRAY__status__c = false
		);
		insert project;
		TASKRAY__Project_Task__c task1 = new TASKRAY__Project_Task__c(
			Name = 'Task 1',
			TASKRAY__Project__c = project.id,
			TASKRAY__List__c = 'Holding'
		);
		insert task1;

		System.currentPageReference().getParameters().put('id', task1.id);
		BLDRNR_TaskToProject controller = new BLDRNR_TaskToProject();
		controller.cancel();
		system.assertEquals(controller.newProject.id, null);
		system.assertEquals(controller.oldTask.name, 'Task 1');
		system.assertEquals(controller.oldTask.TASKRAY__Project__c, project.id);

	}
}