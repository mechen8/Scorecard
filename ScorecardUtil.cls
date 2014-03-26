global with sharing class ScorecardUtil implements Database.Batchable<SObject> {

	// Batch interface for rename and fill values
	public static Id fixAllData() {
		ScorecardUtil batch = new ScorecardUtil(); 
      return Database.executeBatch(batch, 100);        
	}
	global Database.QueryLocator start(Database.BatchableContext BC) {	 	
	   return Database.getQueryLocator(
			[select Id, OwnerId, Name, Actual_Amount__c, Actual_Number__c, Actual_Percent__c, Description__c, 
				Entry_Color__c, Forecast_Amount__c, Forecast_Number__c, Forecast_Percent__c, Goal_Type__c, 
				Metric_Type__c, Metric__c, Parent__c, Percent_of_Goal__c, Scorecard_Date__c, Scorecard_Sort_Order__c, 
				Source_Link__c, Source__c, Subcategory__c, Change_From_Previous__c, Change_Indicator__c, 
				Metric_Unique_Key__c, Percent_Change__c, Previous_Amount__c, Previous_Number__c, Previous_Percent__c, 
				Previous_Values_JSON__c from Scorecard_Entry__c] );
	}
	global void execute(Database.BatchableContext BC, List<Scorecard_Entry__c> batch) {        
		autoname( batch );
		fillPreviousMetricValues( batch );
	   update batch;
	}
	global void finish(Database.BatchableContext BC) {}

	/* autoname method for scorecard entries
	**
	** method to name entries in the form TopLevelParentName - MetricName - Month YYYY
	**
	** the method does not actually update records - if you are not running in a before trigger,
	**   it is important to call update on the list of records
	*/
	public void autoname( list<Scorecard_Entry__c> seList ) {
	    // get parent ids
	    set<Id> parentIDs = new set<Id>();
	    for (Scorecard_Entry__c se : seList) {
	        if (se.Parent__c != null)
	            parentIDs.add(se.Parent__c);
	        if (se.metric__c == null)
	            se.metric__c = se.name;
	    }

	    // get top level names
	    map<Id, Scorecard_Entry__c> parentNameMap = new map<Id, Scorecard_Entry__c>(
	        [select Id, Name, Metric__c, Parent__c, Parent__r.Metric__c,
	                Parent__r.Parent__c, Parent__r.Parent__r.Metric__c, 
	                Parent__r.Parent__r.Parent__c, Parent__r.Parent__r.Parent__r.Metric__c,
	                Parent__r.Parent__r.Parent__r.Parent__c, Parent__r.Parent__r.Parent__r.Parent__r.Metric__c
	            from Scorecard_Entry__c                 
	            where id in : parentIDs]);

	    // name entries in the form: [GreatGrandParentName - [GrandParentName - ]]MetricName - Month YYYY
	    for (Scorecard_Entry__c se : seList) {
	        String s = '';
	        if (se.parent__c != null && parentNameMap.containsKey(se.parent__c)) {
	            Scorecard_Entry__c myParent = parentNameMap.get(se.parent__c);
	            if (myParent.Parent__r.Parent__r.Parent__r.Parent__c != null)
	                s += myParent.Parent__r.Parent__r.Parent__r.Parent__r.Metric__c + ' - ';
	            if (myParent.Parent__r.Parent__r.Parent__c != null)
	                s += myParent.Parent__r.Parent__r.Parent__r.Metric__c + ' - ';
	            if (myParent.Parent__r.Parent__c != null)
	                s += myParent.Parent__r.Parent__r.Metric__c + ' - ';
	            if (myParent.Parent__c != null)
	                s += myParent.Parent__r.Metric__c + ' - ';
	            s += myParent.Metric__c + ' - ';
	        }
	        
	        // next add metric name
	        s += se.Metric__c;

	        // finally date
	        if (se.Scorecard_Date__c != null) {
	 	         // limit the length so we do not exceed 80 chars
		         s = s.abbreviate(69);
	            s += ' - ' + datetime.NewInstance(se.Scorecard_Date__c.year(), 
	            	se.Scorecard_Date__c.month(), 1, 0, 0, 0).format('MMM yyyy');
	        } else {
	        		s = s.abbreviate(80);
	        }

	        // and that is the name
	        se.Name = s;
	    }
	}

	/* fillPreviousMetricValues
	**
	** method to retrieve the last 12 months of values for each scorecard record and 
	**   store them into custom fields
	**
	** does not actually update records - if not running in a before trigger it is important to update them
	**
	** note: the list you pass in must include required fields, e.g.
	**   [select id, Scorecard_Date__c, Metric_Unique_Key__c from Scorecard_Entry__c]
	**
	** every dated scorecard value has a unique key which is a concatenation of the metric hierarchy
	** different dates of the same metric share the key, so we can find previous values of the same key
	*/
	public void fillPreviousMetricValues( list<Scorecard_Entry__c> seList ) {

		// first get the date range and set of "key" values we need
		set<String> keys = new set<String>();
		date firstDate = system.today().addMonths(1);
		date lastDate = system.today().addYears(-10);
		for (Scorecard_Entry__c se : seList) {
			if (se.Scorecard_Date__c != null) {
				if (se.Scorecard_Date__c < firstDate) firstDate = se.Scorecard_Date__c;
				if (se.Scorecard_Date__c > lastDate) lastDate = se.Scorecard_Date__c;
				if (se.Metric_Unique_Key__c != null) 
					keys.add(se.Metric_Unique_Key__c);
			}
		}

		// query for the values in that range and map them to the "key"
		map<String, list<Scorecard_Entry__c>> prevEntries = new map<String, list<Scorecard_Entry__c>>();
		for ( Scorecard_Entry__c se : 
					[select id, Metric_Unique_Key__c, Scorecard_Date__c,
						Forecast_Percent__c, Forecast_Number__c, Forecast_Amount__c, 
						Actual_Percent__c, Actual_Number__c, Actual_Amount__c
						from Scorecard_Entry__c where 
						Scorecard_Date__c != null and
						Scorecard_Date__c >= : firstDate.addYears(-1).toStartOfMonth() and
						Scorecard_Date__c < : lastDate.addMonths(1).toStartOfMonth() and 
						Metric_Unique_Key__c in : keys 
						order by Scorecard_Date__c desc] ) {

			if (!prevEntries.containsKey(se.Metric_Unique_Key__c))
				prevEntries.put( se.Metric_Unique_Key__c, new list<Scorecard_Entry__c>() );

			prevEntries.get( se.Metric_Unique_Key__c ).add( se );
		}

		for (Scorecard_Entry__c se : seList) {
			if ( prevEntries.containsKey(se.Metric_Unique_Key__c) ) {
				list<Scorecard_Entry__c> lastTwelveMonths = new list<Scorecard_Entry__c>();
				Scorecard_Entry__c mostRecent = null;

				// traverse the matching entries for this "key" and grab the ones in the date range
				for ( Scorecard_Entry__c keyMatch : prevEntries.get(se.Metric_Unique_Key__c) ) {
					if ( keyMatch.Scorecard_Date__c < se.Scorecard_Date__c.toStartOfMonth() ) {

						// make sure we haven't gone beyond 12 months ago
						if ( keyMatch.Scorecard_Date__c < se.Scorecard_Date__c.toStartOfMonth().addMonths( -12 ) )
							break;

						if ( mostRecent == null )
							mostRecent = keyMatch;

						lastTwelveMonths.add( keyMatch );
					}
				}
			
				// put the most recent value into the previous month fields
				if (mostRecent != null) {
					se.Previous_Amount__c = mostRecent.Actual_Amount__c;
					se.Previous_Number__c = mostRecent.Actual_Number__c;
					se.Previous_Percent__c = mostRecent.Actual_Percent__c;

					// serialize the other previous data into the previous values field
					se.Previous_Values_JSON__c = JSON.serialize( lastTwelveMonths );			
				}
			}	
		}
	}

	static testMethod void TestFillPreviousScores() {
		Scorecard_Entry__c topLevel1 = new Scorecard_Entry__c(
			Name = 'Parent Entry',
			Metric__c = 'Top Level Metric',
			Metric_Type__c = 'Test',
			Scorecard_SORT_ORDER__c = 1
		);
		insert topLevel1;
		Scorecard_Entry__c topLevel2 = new Scorecard_Entry__c(
			Name = 'Top Level 2',
			Metric__c = 'Top Level 2',
			Metric_Type__c = 'Test',
			Scorecard_SORT_ORDER__c = 2	
		);
		insert topLevel2;
		Scorecard_Entry__c secondLevel1m10 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 1',
			Metric_Type__c = 'Test',
			Parent__c = topLevel1.id,
			Actual_Amount__c = 1.23,
			Scorecard_Date__c = system.today().addMonths(-10),
			Scorecard_SORT_ORDER__c = 3		
		);
		insert secondLevel1m10;
		Scorecard_Entry__c secondLevel1m20 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 1',
			Metric_Type__c = 'Test',
			Parent__c = topLevel1.id,
			Actual_Amount__c = 1234,
			Scorecard_Date__c = system.today().addMonths(-20),
			Scorecard_SORT_ORDER__c = 3		
		);
		insert secondLevel1m20;
		Scorecard_Entry__c secondLevel2m14 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 2',
			Metric_Type__c = 'Test',
			Parent__c = topLevel1.id,
			Actual_Number__c = 12345,
			Scorecard_Date__c = system.today().addMonths(-14),
			Scorecard_SORT_ORDER__c = 4		
		);
		insert secondLevel2m14;
		Scorecard_Entry__c secondLevel1m2 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 1',
			Metric_Type__c = 'Bogus',   // should not matter
			Parent__c = topLevel1.id,
			Actual_Amount__c = 123456,
			Scorecard_Date__c = system.today().addMonths(-2),
			Scorecard_SORT_ORDER__c = 3		
		);
		insert secondLevel1m2;
		Scorecard_Entry__c secondLevel2m2 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 2',
			Metric_Type__c = 'Test',
			Parent__c = topLevel1.id,
			Actual_Number__c = 123,
			Scorecard_Date__c = system.today().addMonths(-2),
			Scorecard_SORT_ORDER__c = 4		
		);
		insert secondLevel2m2;
		Scorecard_Entry__c secondLevel1 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 1',
			Metric_Type__c = 'Test',
			Parent__c = topLevel1.id,
			Actual_Amount__c = 1,
			Scorecard_Date__c = system.today().addMonths(-1),
			Scorecard_SORT_ORDER__c = 3		
		);
		insert secondLevel1;
		Scorecard_Entry__c secondLevel2 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 2',
			Metric_Type__c = 'Test',
			Parent__c = topLevel1.id,
			Actual_Number__c = 1234567,
			Scorecard_Date__c = system.today().addMonths(-1),
			Scorecard_SORT_ORDER__c = 4		
		);
		insert secondLevel2;
		Scorecard_Entry__c thirdLevelm2 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Third Level Metric for Child Metric 1',
			Metric_Type__c = 'Test',
			Parent__c = secondLevel1m2.id,
			Actual_Amount__c = 12,
			Scorecard_Date__c = system.today().addMonths(-2),
			Scorecard_SORT_ORDER__c = 5		
		);
		insert thirdLevelm2;
		Scorecard_Entry__c thirdLevel = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Third Level Metric for Child Metric 1',
			Metric_Type__c = 'Test',
			Parent__c = secondLevel1.id,
			Actual_Amount__c = 12345678,
			Scorecard_Date__c = system.today().addMonths(-1),
			Scorecard_SORT_ORDER__c = 5		
		);
		insert thirdLevel;
		
		// need to query for the keys
		list<Scorecard_Entry__c> seList = 
			[select id, Scorecard_Date__c, Metric_Unique_Key__c, Previous_Values_JSON__c,
				Previous_Amount__c, Previous_Number__c, Previous_Percent__c
				from Scorecard_Entry__c where id 
				in : (new set<id> { 
					topLevel1.id, topLevel2.id, secondLevel1m10.id, secondLevel1m20.id, secondLevel2m14.id, 
					secondLevel1m2.id, secondLevel2m2.id, secondLevel1.id, secondLevel2.id, thirdLevel.id }) 
			];
		
		// run the utility method to fill previous values
		ScorecardUtil util = new ScorecardUtil();
		util.fillPreviousMetricValues( seList );

		map<id, Scorecard_Entry__c> seMap = new map<id, Scorecard_Entry__c>( seList );

		// did it work?
		system.assertEquals( null, seMap.get(topLevel1.id).Previous_Values_JSON__c );
		system.assertEquals( null, seMap.get(topLevel2.id).Previous_Values_JSON__c );
		system.assertEquals( null, seMap.get(secondLevel1m20.id).Previous_Values_JSON__c );
		system.assertEquals( null, seMap.get(secondLevel2m14.id).Previous_Values_JSON__c );
		system.assertEquals( 1234, seMap.get(secondLevel1m10.id).Previous_Amount__c );
		system.assertEquals( 1.23, seMap.get(secondLevel1m2.id).Previous_Amount__c );
		system.assertEquals( 12345, seMap.get(secondLevel2m2.id).Previous_Number__c );
		system.assertEquals( 123456, seMap.get(secondLevel1.id).Previous_Amount__c );
		system.assertEquals( 123, seMap.get(secondLevel2.id).Previous_Number__c );
		system.assertEquals( 12, seMap.get(thirdLevel.id).Previous_Amount__c );

		// JSON should have two entries
		system.debug(logginglevel.WARN, secondLevel1.Previous_Values_JSON__c);
		system.assert( seMap.get(secondLevel1.id).Previous_Values_JSON__c.contains(secondLevel1m10.Id) );
		system.assert( seMap.get(secondLevel1.id).Previous_Values_JSON__c.contains(secondLevel1m2.Id) );
	}

	static testMethod void TestBatch() {
		Scorecard_Entry__c topLevel1 = new Scorecard_Entry__c(
			Name = 'Parent Entry',
			Metric__c = 'Top Level',
			Metric_Type__c = 'Test',
			Scorecard_SORT_ORDER__c = 1
		);
		insert topLevel1;
		Scorecard_Entry__c secondLevel1m2 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 1',
			Metric_Type__c = 'Bogus',   // should not matter
			Actual_Amount__c = 123456,
			Parent__c = topLevel1.id,
			Scorecard_Date__c = system.today().addMonths(-2),
			Scorecard_SORT_ORDER__c = 3		
		);
		insert secondLevel1m2;
		Scorecard_Entry__c secondLevel1 = new Scorecard_Entry__c(
			Name = 'Child Entry',
			Metric__c = 'Child Metric 1',
			Metric_Type__c = 'Test',
			Actual_Amount__c = 1,
			Scorecard_Date__c = system.today().addMonths(-1),
			Scorecard_SORT_ORDER__c = 3		
		);
		insert secondLevel1;

		// name and amount will be wrong after this
		secondLevel1.Parent__c = topLevel1.id;
		update secondLevel1; 
		topLevel1.Metric__c = 'Top Level Metric';
		update topLevel1;

		Scorecard_Entry__c[] check1 = [select id, name, Previous_Amount__c from Scorecard_Entry__c where id = : secondLevel1.id];
		system.assert( !check1[0].name.startsWith('Top Level Metric - Child Metric 1 - ' ));
		system.assertEquals( null, check1[0].Previous_Amount__c );

		Test.startTest();
		ScorecardUtil.fixAllData();
		Test.stopTest();

		Scorecard_Entry__c[] check2 = [select id, name, Previous_Amount__c from Scorecard_Entry__c where id = : secondLevel1.id];
		system.assert( check2[0].name.startsWith('Top Level Metric - Child Metric 1 - ' ));
		system.assertEquals( 123456, check2[0].Previous_Amount__c );
	}
}