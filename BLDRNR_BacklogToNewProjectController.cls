public with sharing class BLDRNR_BacklogToNewProjectController {
	
	public static id projectID {get{
					if(ApexPages.CurrentPage().getParameters().get('id') instanceOf id){
						return ApexPages.CurrentPage().getParameters().get('id');
					} else{
						ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'Must supply a valid id as URL parameter'));
						return null;
					}
					
				}}

	public TASKRAY__Project__c oldProject {get;set;}
	public TASKRAY__Project__c newProject {get;set;}

	public list<selectoption> projectList {get;set;}

	public boolean markOldProjectComplete{get;set;}

	public BLDRNR_BacklogToNewProjectController() {
		if(projectID != null){
			markOldProjectComplete = true;
			cloneCurrentProject();
			getProjectList();
		}
	}


	public void cloneCurrentProject(){
		oldProject = [SELECT id, name, ownerid, TASKRAY__Status__c, Business_Owner__c, Include_in_List__c, Include_in_Tech_Team_Group__c,
				TASKRAY__Project_Parent__c, Description__c,Priority__c, TASKRAY__ProjectColor__c, TASKRAY__Project_End__c, Project_Health__c, TASKRAY__Project_Start__c,
				Project_Status__c, TASKRAY__ChatterGroupSharingIds__c, TASKRAY__Project_Parent__r.name,
				(SELECT id, TASKRAY__Project__c, TASKRAY__List__c
					FROM TASKRAY__Tasks__r
					WHERE (TASKRAY__List__c != 'Completed' OR TASKRAY__List__c != 'Accepted'))
				FROM TASKRAY__Project__c
				WHERE id =:projectID];
		newProject = oldProject.clone();
		newProject.name = oldProject.name + ' vX';
		newProject.Project_Status__c = 'Planned';
		newProject.TASKRAY__Project_Start__c = null;
		newProject.TASKRAY__Project_End__c = null;
		if(oldProject.TASKRAY__Tasks__r.size() == 0){
			ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'There are no tasks in the backlog.'));
		}
	}

	public void getProjectList(){
		projectList = new list<selectoption>();
		if(oldProject.TASKRAY__Project_Parent__c != null){
			selectoption s2 = new selectoption(oldProject.TASKRAY__Project_Parent__c, oldProject.TASKRAY__Project_Parent__r.name + ' (sibling of ' + oldProject.name +')');
			projectList.add(s2);
		}
		selectoption s1 = new selectoption(oldProject.id, oldProject.name + ' (child of ' + oldProject.name +')');
		projectList.add(s1);
		selectoption s3 = new selectoption('', 'No Parent');
		projectList.add(s3);
		// list<TASKRAY__Project__c> projects = [select id, name from TASKRAY__Project__c where TASKRAY__Status__c = false AND TASKRAY__Parent_Project__c = null ORDER BY Name ASC];
		// for(TASKRAY__Project__c p :projects){
		// 	if(p.id != oldProject.id){
		// 		selectoption s = new selectoption(p.id, p.name);
		// 		projectList.add(s);
		// 	}
		// }
	}

	public pageReference saveProject(){
		if(validData()){
			insert newProject;
			list<TASKRAY__Project_Task__c> tasksToUpdate = new list<TASKRAY__Project_Task__c>();
			for(TASKRAY__Project_Task__c t :oldProject.TASKRAY__Tasks__r){
					t.TASKRAY__Project__c = newProject.id;
					tasksToUpdate.add(t);
			}
			if(tasksToUpdate.size() > 0){
				update tasksToUpdate;
			}
			if(markOldProjectComplete){
				oldProject.Project_Status__c = 'Completed';
				update oldProject;
			}
			pageReference pr = new pageReference('/apex/TASKRAY__trprojectboard?projectid='+newProject.id);
			return pr;
		}else{
			ApexPages.AddMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'Replace vX in the Project Name with the version of this new project'));
			return null;
		}
	}

	public pageReference cancel(){
		pageReference pr = new pageReference('/'+oldProject.id);
		return pr;
	}

	public boolean validData(){
		if(newProject.name == oldProject.name + ' vX'){
			return false;
		}
		else{
			return true;
		}
	}

	static testmethod void convertBacklogTest(){
		TASKRAY__Project__c parentProject = new TASKRAY__Project__c(
			Name = 'Parent Project',
			TASKRAY__status__c = false
		);
		insert parentProject;
		TASKRAY__Project__c project = new TASKRAY__Project__c(
			Name = 'Project',
			TASKRAY__status__c = false,
			TASKRAY__Project_Parent__c = parentProject.id
		);
		insert project;
		TASKRAY__Project_Task__c task1 = new TASKRAY__Project_Task__c(
			Name = 'Task 1',
			TASKRAY__Project__c = project.id,
			TASKRAY__List__c = 'Holding'
		);
		insert task1;

		System.currentPageReference().getParameters().put('id', project.id);
		BLDRNR_BacklogToNewProjectController controller = new BLDRNR_BacklogToNewProjectController();
		controller.newProject.name = 'Project v2';
		controller.saveProject();
		system.assertNotEquals(controller.newProject.id, null);
		TASKRAY__Project_Task__c t = [select id, TASKRAY__Project__c from TASKRAY__Project_Task__c where id =:task1.id];
		system.assertEquals(controller.newProject.id, t.TASKRAY__Project__c);
		system.assertEquals(controller.oldProject.Project_Status__c, 'Completed');


	}

	static testmethod void convertBacklogCancelTest(){
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

		System.currentPageReference().getParameters().put('id', project.id);
		BLDRNR_BacklogToNewProjectController controller = new BLDRNR_BacklogToNewProjectController();
		controller.cancel();
		system.assertEquals(controller.newProject.id, null);
		system.assertEquals(controller.oldProject.TASKRAY__Tasks__r.size(), 1);
		system.assertEquals(controller.oldProject.TASKRAY__Tasks__r[0].TASKRAY__Project__c, project.id);

	}

}