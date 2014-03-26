public without sharing class BLDRNR_ProjectStatusController {
	
	public class ProjectRow {
		public TASKRAY__Project__c project {get;set;}
		public list<ProjectRow> childRows {get;private set;}
		public Integer level {get;private set;}
		public FeedItem post {get;set;}
		public User postUser {get;set;}
		public String category {get;set;}
		public Boolean hasTasks {get;set;}
		public Boolean hasHolding {get;set;}
		public Boolean hasPrioritized {get;set;}
		public Boolean hasStarted {get;set;}
		public Boolean hasCompleted {get;set;}

		public ProjectRow(BLDRNR_ProjectStatusController psc, TASKRAY__Project__c proj, Integer lvl, String cat) {
			project = proj;
			level = lvl;
			childRows = new list<ProjectRow>();
			category = proj.Include_in_List__c;
			//category = cat;  // we could set the category always to the parent category

			hasTasks = (proj.Total_Tasks__c != null && proj.Total_Tasks__c > 0);
			hasHolding = (proj.Total_Tasks_in_Holding__c != null && proj.Total_Tasks_in_Holding__c > 0);
			hasPrioritized = (proj.Total_Tasks_Prioritized__c != null && proj.Total_Tasks_Prioritized__c > 0);
			hasStarted = (proj.Total_Tasks_Started__c != null && proj.Total_Tasks_Started__c > 0);
			hasCompleted = (proj.Total_Tasks_Completed__c != null && proj.Total_Tasks_Completed__c > 0);

			if (proj.TASKRAY__Project_Parent__r != null ) {
				for (TASKRAY__Project__c child : proj.TASKRAY__Project_Parent__r) {
					if (psc.projectMap.containsKey( child.Id )) {
						ProjectRow row = new ProjectRow( psc, psc.projectMap.get( child.Id ), lvl + 1, category );
						childRows.add( row );
						psc.rowMap.put( child.Id, row );
					}
				}
			}
		}
	}

	// these are for internal use while setting up
	private list<TASKRAY__Project__c> projects = new list<TASKRAY__Project__c>();
	public map<id, TASKRAY__Project__c> projectMap = new map<id, TASKRAY__Project__c>();
	public map<id, ProjectRow> rowMap = new map<id, ProjectRow>();
	public set<String> filterSet = new set<String>();

	// these get used on the page
	public list<ProjectRow> allRows {get;set;}
	public Boolean userCanEdit {get; private set;}
	public list<SelectOption> filterOptions {get; private set;}

	public static String baseURL {get{return URL.getSalesforceBaseUrl().toExternalForm();}}
	
	public static String filter {get{
					if(ApexPages.CurrentPage().getParameters().get('filter') != null){
						return ApexPages.CurrentPage().getParameters().get('filter').capitalize();
					} else{
						return null;
					}
					
				}}
	
	public BLDRNR_ProjectStatusController(){
		getAllData();
		createProjectRows();
		arrangeProjects();
		getChatter();
		fillFilterList();
	}
	
	public void getAllData(){
		// first get all the parent ids so we can be sure not to filter them out
		set<id> parentIds = new set<id>();
		for (TASKRAY__Project__c p : 
			[select id, TASKRAY__Project_Parent__c, 
				TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c, 
				TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c,
				TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c,
				TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c
				from TASKRAY__Project__c 
				where TASKRAY__status__c = false AND Project_Status__c != 'New Project']) {

			parentIds.add(p.TASKRAY__Project_Parent__c);
			parentIds.add(p.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c);
			parentIds.add(p.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c);
			parentIds.add(p.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c);
			parentIds.add(p.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__r.TASKRAY__Project_Parent__c);
		}

		// now get the full list of projects
		projects =
			[select id, Name, TASKRAY__project_start__c, TASKRAY__project_end__c, 
				Project_Health__c, Description__c, Include_in_List__c, Project_Status__c, 
				Priority__c, Business_Owner__c, OwnerId, Owner.Name, Total_Tasks__c,
				Total_Tasks_in_Holding__c, Total_Tasks_Prioritized__c, Total_Tasks_Started__c, Total_Tasks_Completed__c, 
				Start_Date_Alert__c, Days_To_Project_Start__c, End_Date_Alert__c, Days_To_Project_End__c, TASKRAY__Project_Parent__c, 
				(select id from TASKRAY__Project_Parent__r order by Priority__c DESC NULLS LAST, TASKRAY__project_start__c ASC NULLS LAST, createdDate) 
				from TASKRAY__Project__c 
				where (TASKRAY__status__c = false AND Project_Status__c != 'New Project') OR Id in :parentIds
				order by Priority__c DESC NULLS LAST, TASKRAY__project_start__c ASC NULLS LAST, createdDate];

		projectMap.putAll( projects );
	}
	
	public void createProjectRows(){
		for (TASKRAY__Project__c proj : projects) {
			if (proj.TASKRAY__Project_Parent__c == null) {
				ProjectRow thisRow = new ProjectRow(this, proj, 0, proj.Include_in_List__c);
				rowMap.put(proj.id, thisRow);
			}
			// create filter lists
			if (proj.Include_in_List__c != null) 
				filterSet.addAll(proj.Include_in_List__c.split(';'));
		}
		//system.debug(loggingLevel.WARN, rowMap);
	}

	public void arrangeProjects(){
		// now put them all into the list in the proper order
		allRows = new list<ProjectRow>();
		for (TASKRAY__Project__c proj : projects) {
			if (proj.TASKRAY__Project_Parent__c == null) {
				ProjectRow parentRow = rowMap.get(proj.id);
				allRows.add(parentRow);
				arrangeChildProjects(parentRow);
			}
		}
		//system.debug(loggingLevel.WARN, allRows);
	}

	public void arrangeChildProjects(ProjectRow parentRow){
		for (ProjectRow row : parentRow.childRows) {
			allRows.add(row);
			arrangeChildProjects(row);		
		}
	}
	
	public void fillFilterList(){
		list<String> filterList = new list<String>(filterSet);
		filterList.sort();
		filterOptions = new list<SelectOption>();
		if (filterList.isEmpty()) 
			filterList.add('All');
		else 
			filterList.add(0, 'All');

		for (String s : filterList)
			filterOptions.add(new SelectOption(s, s));
	}

	public void getChatter(){

		list<id> allUserIDs = new list<id>();
		map<id, FeedItem> postMap = new map<id, FeedItem>();

		for(FeedItem c : 
				[select id, body, parentID, createdDate, createdBy.Id from FeedItem 
					where ParentID =:projectMap.keyset() ORDER BY CreatedDate DESC LIMIT 1000]){

			if(!postMap.containsKey(c.parentId) && c.body != null && c.body.contains('#update')){
				allUserIDs.add(c.createdBy.Id);
				postMap.put(c.parentId, c);
			}
		}
		map<id, User> userMap = new map<id, User>(
			[select id, firstName, lastName, SmallPhotoUrl from User where id = :allUserIds]);

		for (ProjectRow pr : allRows ) {
			pr.post = postMap.get( pr.project.Id );
			pr.postUser = userMap.get( pr.post.createdBy.Id );
		}
	}

	@RemoteAction
	public static Database.SaveResult saveProject( String projectJson ) {  //Id projectId, String projectHealth, Date start, Date end ) 
/*		TASKRAY__Project__c proj = new TASKRAY__Project__c( 
			id = projectId,
			Project_Health__c = projectHealth
		);
		TASKRAY__Project__c proj = ((TASKRAY__Project__c)(JSON.deserialize(projectJson, TASKRAY__Project__c.class)));
*/
		TASKRAY__Project__c proj = ((TASKRAY__Project__c)(JSON.deserialize(projectJson, TASKRAY__Project__c.class)));
		if (proj.id == null)
			return (Database.insert( proj, true ));
		else
			return (Database.update( proj, true ));
	}
	
	public class parentProject{
		public id parentProjectID {get;set;}
		public TASKRAY__Project__c parentProject {get;set;}
		public list<TASKRAY__Project__c> childProjects {get;set;}
	}
	
	static testMethod void RemoteUpdate(){
		TASKRAY__Project__c proj = new TASKRAY__Project__c(
			Name = 'Parent Project',
			TASKRAY__status__c = false
		);
		insert proj;
		
		proj.Project_Health__c = 'Green';
		saveProject( JSON.Serialize(proj) );

		TASKRAY__Project__c[] se = [select id, name, Project_Health__c from TASKRAY__Project__c 
			where id = : proj.id];
		system.assertEquals('Green', se[0].Project_Health__c);		
	}

	static testMethod void ProjectStatusPage(){
		TASKRAY__Project__c parent = new TASKRAY__Project__c(
			Name = 'Parent Project',
			Project_Status__c = 'In Progress',
			TASKRAY__status__c = false
		);
		insert parent;
		TASKRAY__Project__c childActive = new TASKRAY__Project__c(
			Name = 'Child Project',
			TASKRAY__Project_Parent__c = parent.id,
			Project_Status__c = 'In Progress',
			TASKRAY__status__c = false
		);
		insert childActive;
		TASKRAY__Project__c childActive2 = new TASKRAY__Project__c(
			Name = 'Child Project',
			TASKRAY__Project_Parent__c = parent.id,
			Project_Status__c = 'On Hold',
			TASKRAY__status__c = false
		);
		insert childActive2;
		TASKRAY__Project__c parent2 = new TASKRAY__Project__c(
			Name = 'Parent Project 2',
			Project_Status__c = 'Completed',
			TASKRAY__status__c = false,
			Include_In_List__c = 'Key'
		);
		insert parent2;
		TASKRAY__Project__c parent3 = new TASKRAY__Project__c(
			Name = 'Parent Project 3',
			Project_Status__c = 'New Project',
			TASKRAY__status__c = false,
			Include_In_List__c = 'Key'
		);
		insert parent3;
		childActive.TASKRAY__Project_Parent__c = parent2.id;
		update ChildActive;
		FeedItem fitem = new FeedItem(
			body = 'this is an #update',
			parentID = parent.id
		);
		insert fitem;
		
		id myProfileID = AppUtil.SYSADMIN_PROFILE.id;
		
		User myUser;
		User adminUser = [select id from user where profileid = : myProfileID and isActive = true limit 1];
		system.runAs(adminUser){
			myUser = new User(
				username = 'testuser@salesforcefoundation.org.tests',
				email = 'testuser@salesforcefoundation.org.tests',
				firstname = 'Testy',
				lastname = 'McTester',
				profileID = myProfileID,
				alias = 'tifbs',
				emailencodingkey='UTF-8',
				languagelocalekey='en_US',
				localesidkey='en_US',
				timezonesidkey='America/Los_Angeles');
			insert myUser;
		}
		
		system.runAs(myUser){
			BLDRNR_ProjectStatusController controller = new BLDRNR_ProjectStatusController();
			system.assertEquals(4,controller.projectMap.size());
			system.assertEquals(4,controller.allRows.size());
			system.assertEquals(1,controller.rowMap.get(parent2.id).childRows.size());
			system.assertEquals(1,controller.rowMap.get(parent.id).childRows.size());
			system.assert(controller.rowMap.get(parent.id).post.body == 'this is an #update');
			system.assert(baseURL == URL.getSalesforceBaseUrl().toExternalForm());
			system.assert(filter == null);

			System.currentPageReference().getParameters().put('filter', 'Key');
			controller = new BLDRNR_ProjectStatusController();
			system.assert(filter == 'Key');
		}
		
	}	
}