public with sharing class BLDRNR_ProjectTaskRollups {

	public static map<id, TASKRAY__Project__c> projectMap;
	public static map<id, TASKRAY__Project__c> projectsToUpdate;

	public static map<id, TASKRAY__Project__c> parentProjectMap;
	public static map<id, TASKRAY__Project__c> parentProjectsToUpdate;

	//get tasks from trigger, kick off rollups
	public static void rollupFromTrigger(list<TASKRAY__Project_Task__c> newtasks, list<TASKRAY__Project_Task__c> oldtasks){
		list<id> taskIDs = new list<id>();
		if(newTasks != null){
			for(TASKRAY__Project_Task__c t :newtasks){
				taskIDs.add(t.TASKRAY__Project__c);
			}
		}
		if(oldTasks != null){
			for(TASKRAY__Project_Task__c t :oldtasks){
				taskIDs.add(t.TASKRAY__Project__c);
			}
		}
		getProjects(taskIDs);
		doRollupTotals();
		updateProjects();
	}

	//get projects tasks are associated with, create maps for old and new values
	public static void getProjects(list<id> taskIDs){

		list<TASKRAY__Project__c> allProjects = new list<TASKRAY__Project__c>();
		if(taskIDs == null){
			allProjects = [select id, name, Total_Tasks__c, Total_Tasks_Completed__c, Total_Tasks_in_Holding__c, Total_Tasks_Started__c, Total_Tasks_Prioritized__c from TASKRAY__Project__c];
		}else{
			allProjects = [select id, name, TASKRAY__Project_Parent__c, Total_Tasks__c, Total_Tasks_Completed__c, Total_Tasks_in_Holding__c, Total_Tasks_Started__c, Total_Tasks_Prioritized__c from TASKRAY__Project__c WHERE id =: taskIDs];
		}

		projectMap = new map<id, TASKRAY__Project__c>();
		projectMap.putAll(allProjects);

		projectsToUpdate = new map<id, TASKRAY__Project__c>();
		for(id pid :projectMap.keySet()){
			projectsToUpdate.put(pid, new TASKRAY__Project__c(
				id = pid,
				TASKRAY__Project_Parent__c = projectMap.get(pid).TASKRAY__Project_Parent__c,
				Total_Tasks__c = 0,
				Total_Tasks_Completed__c = 0,
				Total_Tasks_in_Holding__c = 0,
				Total_Tasks_Started__c = 0,
				Total_Tasks_Prioritized__c = 0
				));
		}
	}

	//get task totals for projects with SOQL aggregate query
	public static void doRollupTotals(){
		
		//get aggregate count of tasks by list
		list<sobject> ars = [SELECT TASKRAY__List__c status, TASKRAY__Project__c pid, COUNT(id) cnt
			FROM TASKRAY__Project_Task__c
			GROUP BY ROLLUP(TASKRAY__Project__c, TASKRAY__List__c)
			HAVING TASKRAY__Project__c =: projectMap.keySet()];
		//for each row, put the total in the right project record and field
		system.debug('ars : '+ars );
		for(sobject ar :ars){
			id pid = (id)ar.get('pid');
			if(pid != null){
				updateProjectFromRollup(projectsToUpdate.get(pid), ar);
			}
		}

	}

	//Method to update the project based on an aggregate total row
	public static void updateProjectFromRollup(TASKRAY__Project__c p, sobject ar){
		integer count = (integer)ar.get('cnt');
		if(count!=null){
			if(ar.get('status') == null){
				p.Total_Tasks__c = count;
			}
			if(ar.get('status') == 'Finished' || ar.get('status') == 'Completed' || ar.get('status') == 'Accepted'){
				p.Total_Tasks_Completed__c = count;
			}
			if(ar.get('status') == 'Holding'){
				p.Total_Tasks_in_Holding__c = count;
			}
			if(ar.get('status') == 'Prioritized'){
				p.Total_Tasks_Prioritized__c = count;
			}
			if(ar.get('status') == 'Started'){
				p.Total_Tasks_Started__c = count;
			}
		}

	}

	//Check to see if the project has been updated, if so, commit the updates
	public static void updateProjects(){
		//check records to see if they've changed
		for(id i :projectMap.keySet()){
			TASKRAY__Project__c p1 = projectMap.get(i);
			TASKRAY__Project__c p2 = projectsToUpdate.get(i);

			if(p1.Total_Tasks__c == p2.Total_Tasks__c &&
				p1.Total_Tasks_Completed__c == p2.Total_Tasks_Completed__c &&
				p1.Total_Tasks_in_Holding__c == p2.Total_Tasks_in_Holding__c &&
				p1.Total_Tasks_in_Holding__c == p2.Total_Tasks_Prioritized__c &&
				p1.Total_Tasks_in_Holding__c == p2.Total_Tasks_Started__c ){
				projectsToUpdate.remove(i);
			}
		}
		//commit the updates
		update projectsToUpdate.values();
		//send the records to the hierarchy rollups
		list<id> newParentsIDs = new list<id>();
		newParentsIDs.addAll(projectsToUpdate.keySet());
		rollupHierarchy(newParentsIDs);
	}

	/*********BEGIN HIERARCHY ROLLUPS ***********/

	//get project ids, kick off rollups
	public static void rollupHierarchy(list<id> projects){
		getParentProjects(projects);
		doHierarchyRollupTotals();
		updateParentProjects();
	}

	//get projects, create maps for old and new values
	public static void getParentProjects(list<id> projects){
		
		//get the parent projects that we're rolling up
		list<TASKRAY__Project__c> parentProjects = new list<TASKRAY__Project__c>();
		if(projects.size() != 0){
			parentProjects = [select id, name, TASKRAY__Project_Parent__c, Total_Tasks_in_Hierarchy__c, Total_Tasks_Completed_in_Hierarchy__c, Total_Tasks_in_Holding_in_Hierarchy__c, Total_Tasks_Started_in_Hierarchy__c, Total_Tasks_Prioritized_in_Hierarchy__c,
				Total_Tasks__c, Total_Tasks_Completed__c, Total_Tasks_in_Holding__c, Total_Tasks_Started__c, Total_Tasks_Prioritized__c, (select id from TASKRAY__Project_Parent__r)
				FROM TASKRAY__Project__c
				WHERE id = :projects];
		}
		
		parentProjectMap = new map<id, TASKRAY__Project__c>();
		parentProjectMap.putAll(parentProjects);
		system.debug('keyset: '+parentProjectMap.keyset());
		parentProjectsToUpdate = new map<id, TASKRAY__Project__c>();
		for(id pid :parentProjectMap.keySet()){
			parentProjectsToUpdate.put(pid, new TASKRAY__Project__c(
				id = pid,
				TASKRAY__Project_Parent__c = parentProjectMap.get(pid).TASKRAY__Project_Parent__c,
				Total_Tasks_in_Hierarchy__c = 0,
				Total_Tasks_Completed_in_Hierarchy__c = 0,
				Total_Tasks_in_Holding_in_Hierarchy__c = 0,
				Total_Tasks_Started_in_Hierarchy__c = 0,
				Total_Tasks_Prioritized_in_Hierarchy__c = 0
				));
			//if this is a project with no children below it in the hierarchy, use it's own task totals.
			if(parentProjectMap.get(pid).TASKRAY__Project_Parent__r.size() == 0){
				system.debug('revert');
				useTaskTotalAsHierarchy(parentProjectsToUpdate.get(pid));
			}
		}
	}

	//get hierarchy task totals for child projects with SOQL aggregate query
	public static void doHierarchyRollupTotals(){
		//get aggregate count of hierarchy tasks
		list<sobject> ars = [SELECT TASKRAY__Project_Parent__c pid,
				SUM(Total_Tasks_in_Hierarchy__c) total,
				SUM(Total_Tasks_Completed_in_Hierarchy__c) completed,
				SUM(Total_Tasks_in_Holding_in_Hierarchy__c) holding,
				SUM(Total_Tasks_Started_in_Hierarchy__c) started,
				SUM(Total_Tasks_Prioritized_in_Hierarchy__c) prioritized
    		FROM TASKRAY__Project__c
			GROUP BY TASKRAY__Project_Parent__c
			HAVING TASKRAY__Project_Parent__c =: parentProjectMap.keyset()];
		
		system.debug('ars : '+ars );
		
		for(sobject ar :ars){
			id pid = (id)ar.get('pid');
			system.debug(pid+' : '+ar );
			updateParentProjectFromRollup(parentProjectsToUpdate.get(pid), ar);
		}

	}

	//method to use current task total as the hierarchy for bottom level tasks
	public static void useTaskTotalAsHierarchy(TASKRAY__Project__c p){
		p.Total_Tasks_in_Hierarchy__c = parentProjectMap.get(p.id).Total_Tasks__c;
		p.Total_Tasks_Completed_in_Hierarchy__c = parentProjectMap.get(p.id).Total_Tasks_Completed__c;
		p.Total_Tasks_in_Holding_in_Hierarchy__c = parentProjectMap.get(p.id).Total_Tasks_in_Holding__c;
		p.Total_Tasks_Started_in_Hierarchy__c = parentProjectMap.get(p.id).Total_Tasks_Started__c;
		p.Total_Tasks_Prioritized_in_Hierarchy__c = parentProjectMap.get(p.id).Total_Tasks_Prioritized__c;
	}

	//Method to update the project based on an aggregate total row
	public static void updateParentProjectFromRollup(TASKRAY__Project__c p, sobject ar){

		if(ar.get('total') != null){
			p.Total_Tasks_in_Hierarchy__c = (decimal)ar.get('total');
			if(parentProjectMap.get(p.id).Total_Tasks__c != null){
				p.Total_Tasks_in_Hierarchy__c = p.Total_Tasks_in_Hierarchy__c + parentProjectMap.get(p.id).Total_Tasks__c; 
			}
		}
		if(ar.get('completed') != null){
			p.Total_Tasks_Completed_in_Hierarchy__c = (decimal)ar.get('completed');
			if(parentProjectMap.get(p.id).Total_Tasks_Completed__c != null){
				p.Total_Tasks_Completed_in_Hierarchy__c = p.Total_Tasks_Completed_in_Hierarchy__c + parentProjectMap.get(p.id).Total_Tasks_Completed__c; 
			}
		}
		if(ar.get('holding') != null){
			p.Total_Tasks_in_Holding_in_Hierarchy__c = (decimal)ar.get('holding');
			if(parentProjectMap.get(p.id).Total_Tasks_in_Holding__c != null){
				p.Total_Tasks_in_Holding_in_Hierarchy__c = p.Total_Tasks_in_Holding_in_Hierarchy__c + parentProjectMap.get(p.id).Total_Tasks_in_Holding__c; 
			}
		}
		if(ar.get('started') != null){
			p.Total_Tasks_Started_in_Hierarchy__c = (decimal)ar.get('started');
			if(parentProjectMap.get(p.id).Total_Tasks_Started__c != null){
				p.Total_Tasks_Started_in_Hierarchy__c = p.Total_Tasks_Started_in_Hierarchy__c + parentProjectMap.get(p.id).Total_Tasks_Started__c; 
			}
		}
		if(ar.get('prioritized') != null){
			p.Total_Tasks_Prioritized_in_Hierarchy__c = (decimal)ar.get('prioritized');
			if(parentProjectMap.get(p.id).Total_Tasks_Prioritized__c != null){
				p.Total_Tasks_Prioritized_in_Hierarchy__c = p.Total_Tasks_Prioritized_in_Hierarchy__c + parentProjectMap.get(p.id).Total_Tasks_Prioritized__c; 
			}
		}
	}

	public static void updateParentProjects(){
		//check to see if project hierarchy totals have changed
		for(id i :parentProjectMap.keySet()){
			TASKRAY__Project__c p1 = parentProjectMap.get(i);
			TASKRAY__Project__c p2 = parentProjectsToUpdate.get(i);

			if(p1.Total_Tasks_in_Hierarchy__c == p2.Total_Tasks_in_Hierarchy__c &&
				p1.Total_Tasks_Completed_in_Hierarchy__c == p2.Total_Tasks_Completed_in_Hierarchy__c &&
				p1.Total_Tasks_in_Holding_in_Hierarchy__c == p2.Total_Tasks_in_Holding_in_Hierarchy__c &&
				p1.Total_Tasks_in_Holding_in_Hierarchy__c == p2.Total_Tasks_Prioritized_in_Hierarchy__c &&
				p1.Total_Tasks_in_Holding_in_Hierarchy__c == p2.Total_Tasks_Started_in_Hierarchy__c ){
				parentProjectsToUpdate.remove(i);
			}
		}
		system.debug('updateSize: '+parentProjectsToUpdate.values().size());
		if(parentProjectsToUpdate.values().size() > 0){
			//commit the updates
			update parentProjectsToUpdate.values();
			system.debug('projects updated');
			//check to see if we have any parents to recalculate
			list<id> newParentsIDs = new list<id>();
			for(TASKRAY__Project__c p : parentProjectsToUpdate.values()){
				system.debug('project: '+p.id+' parent: '+p.TASKRAY__Project_Parent__c);
				newParentsIDs.add(p.TASKRAY__Project_Parent__c);
			}
			system.debug('parentListSize: '+newParentsIDs.size());
			//if there are parent projects, recalculate their hierarchy too
			if(newParentsIDs.size() > 0){
				rollupHierarchy(newParentsIDs);
			}
		}
	}


	//test the rollups!
	static testmethod void testProjectRollups(){
		TASKRAY__Project__c parentProject = new TASKRAY__Project__c(
			Name = ' Parent Project',
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
		TASKRAY__Project_Task__c task2 = new TASKRAY__Project_Task__c(
			Name = 'Task 1',
			TASKRAY__Project__c = project.id,
			TASKRAY__List__c = 'Prioritized'
		);
		insert task2;
		TASKRAY__Project_Task__c task3 = new TASKRAY__Project_Task__c(
			Name = 'Task 1',
			TASKRAY__Project__c = parentProject.id,
			TASKRAY__List__c = 'Started'
		);
		insert task3;
		TASKRAY__Project__c uproject = [select id, Total_Tasks__c, Total_Tasks_in_Hierarchy__c from TASKRAY__Project__c WHERE id =: project.id];
		system.assert(uproject.Total_Tasks__c == 2);
		system.assert(uproject.Total_Tasks_in_Hierarchy__c == 2);
		TASKRAY__Project__c uparentProject = [select id, Total_Tasks__c, Total_Tasks_in_Hierarchy__c from TASKRAY__Project__c WHERE id =: parentProject.id];
		system.assertEquals(uparentProject.Total_Tasks__c, 1);
		system.assert(uparentProject.Total_Tasks_in_Hierarchy__c == 3);
	}
}