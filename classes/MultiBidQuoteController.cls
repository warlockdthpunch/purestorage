public with sharing class MultiBidQuoteController {
    /*-=====================================================================
    * Name: MultiBidQuoteController
    * Description: Main controller Class for Multi Bid Quote Generation 
                   has a collection of Methods related to the Multi Bid Quote 
                   Generation
    * Created Date: April 24, 2020
    * Created By: Shankar mallick
    *  ===================================================================== 
    * Method 1 : 
    * Description :
    * input parameters :
    * output parameters:     
    * Date Modified      Modified By                  Description of the update
    *  ===================================================================== */
    public MultiBidQuoteController() {

    }

    @AuraEnabled(cacheable= true)
    public static  Map<String, List<String>> verifyMultiBidQuote(String quoteId){
        // Declare the variables here
        Map<String, List<String>> returnMap = new Map<String, List<String>>();
        List<String> messageList = new List<String>();
        List<String> distributorList = new List<String>();
        List<String> partnerList = new List<String>();
        String errorMessage;
        // Get the Quote Details if quoteId is not blank
        if(String.isNotBlank(quoteId)){
            SBQQ__Quote__c quoteRecord = getQuoteDetails(quoteId);
            if(quoteRecord.SBQQ__Status__c != 'Approved'){
                messageList.add('Seconday Quotes can only be generated for Approved Quotes');
            }
            if(!quoteRecord.SBQQ__Primary__c){
                messageList.add('Seconday Quotes can only be generated for Primary Quotes');
            }
        } else {
            messageList.add('Quote Id cannot be blank');
        }

        if(messageList.size()>0){
            returnMap.put('ERROR', messageList);
        } else {
            distributorList = getListOfDistributor();
            if(distributorList.size()>0){
                returnMap.put('Distributor', distributorList);
            }
            partnerList = getListOfPartner();
            if(partnerList.size()>0){
                returnMap.put('Partner', distributorList);
            }
        }
        return returnMap;
    }

    @AuraEnabled(cacheable = true)
    public static string cloneQuoteAndRelated(String quoteId, String partnerId, String distributorId, Decimal percentageChange ){
        Savepoint sp = Database.setSavepoint();

        // Declare the variables here
        //SBQQ__Quote__c  = new SBQQ__Quote__c();
        String newQuoteId;
        String returnString;
        try{
            //Clone the Quote - ONLY INCLUDE THE FIELDS YOU WANT TO CLONE
            SBQQ__Quote__c  origQuoteRecord = [Select Id, Name, RecordTypeId, Registered_By__c, ApprovalStatus__c, Partner_SE__c, Partner_AE__c, Distributor_Approver__c,CPQ_Distributor_Approver__c, 
                    Partner_AE_User__c,OpportunityOwner__c, SBQQ__Status__c, SBQQ__Account__c,SBQQ__Distributor__c,SBQQ__Source__c,SBQQ__Opportunity2__c,SBQQ__OriginalQuote__c,SBQQ__Partner__c, 
                    SBQQ__PriceBook__c,SBQQ__PrimaryContact__c,SBQQ__SalesRep__c,Global_Account_Manager__c, CPQ_Support_Provider__c, DR_Assumption__c   FROM SBQQ__Quote__c WHERE Id = : quoteId LIMIT 1];
            SBQQ__Quote__c clonedQuoteRecord = origQuoteRecord.clone(false);
            clonedQuoteRecord.ApprovalStatus__c = 'Pending';
            clonedQuoteRecord.SBQQ__Status__c = 'Draft';
            insert clonedQuoteRecord;

            // Set the id of the new Quote created for testing
            newQuoteId = clonedQuoteRecord.Id;
            // Update the partner details on the Cloned Quote 
            updatePartnerOnClonedQuote(quoteId, newQuoteId, partnerId, distributorId);
            returnString ='SUCCESS';
            // Clone the Quote Lines
            List<SBQQ__QuoteLine__c> clonedQuoteLineList = cloneQuoteLines(quoteId, newQuoteId);
            // Clone Quote Line Groups
            List<SBQQ__QuoteLineGroup__c> clonedQuoteLineGroup = cloneQuoteGroups(quoteId, newQuoteId);
        } catch(Exception ex) {
            // roll everything back in case of error
            Database.rollback(sp);
            returnString ='ERROR';
            System.debug('Exception :: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        } 
        return returnString;
    }

    private static void updatePartnerOnClonedQuote(String origQuoteId, String clonedQuoteId, String partnerId, String distributorId){
        SBQQ__Quote__c quoteRecord = [Select Id, Name, MultiBidPrimaryQuote__c,	MultiBidPartner__c FROM SBQQ__Quote__c WHERE Id = : clonedQuoteId LIMIT 1];
        quoteRecord.MultiBidPrimaryQuote__c = origQuoteId;
        quoteRecord.MultiBidPartner__c = partnerId;
        Update quoteRecord;
    }

    private static List<SBQQ__QuoteLine__c> cloneQuoteLines(String origQuoteId, String clonedQuoteId){
        // Declare the variables here
        List<SBQQ__QuoteLine__c> quoteItemsList = new List<SBQQ__QuoteLine__c>();
        // copy over the Quote Line Items - ONLY INCLUDE THE FIELDS YOU WANT TO CLONE
        for (SBQQ__QuoteLine__c qli : [Select Id, Name, CPQ_Site_Address__c, CPQ_Asset__c, SBQQ__OriginalQuoteLineId__c, SBQQ__RenewedAsset__c, SBQQ__RenewedSubscription__c, 
                SBQQ__RequiredBy__c, SBQQ__Source__c, SBQQ__UpgradedSubscription__c, SBQQ__ContractedPrice__c, SBQQ__Dimension__c,SBQQ__Favorite__c, SBQQ__Group__c, 
                SBQQ__ProductOption__c, SBQQ__Product__c, SBQQ__Quote__c, SBQQ__Discount__c, SBQQ__AdditionalDiscountAmount__c, CPQ_Additional_Disti_Discount__c, 
                CPQ_User_Discount__c, Disti_Additional_Partner_Discount__c, SBQQ__AdditionalQuantity__c,SBQQ__DiscountTier__c, SBQQ__DistributorDiscount__c, 
                SBQQ__DiscountScheduleType__c, SBQQ__DiscountSchedule__c,SBQQ__Description__c, SBQQ__DefaultSubscriptionTerm__c,CPQ_Deals_Desk_Discount_Approval__c, 
                CPQ_Darksite__c,SBQQ__CustomerPrice__c,CPQ_Display_Category__c,SBQQ__CostEditable__c,SBQQ__Cost__c,SBCF_Controller__c, Contract_License_Type__c, 
                Contract_License_Needed__c,SBQQ__CompoundDiscountRate__c, SBQQ__ComponentListTotal__c From SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = : origQuoteId]) {
            SBQQ__QuoteLine__c newQuoteLine = qli.clone(false);
            newQuoteLine.SBQQ__Quote__c = clonedQuoteId; 
            quoteItemsList.add(newQuoteLine);
        }
        if(quoteItemsList.size()>0){
            insert quoteItemsList;
        }
        return quoteItemsList;
    }

    private static List<SBQQ__QuoteLineGroup__c> cloneQuoteGroups(String origQuoteId, String clonedQuoteId){
        // Declare the variables here
        List<SBQQ__QuoteLineGroup__c> quoteLineGroupList = new List<SBQQ__QuoteLineGroup__c>();
         // copy over the Quote Line Groups - ONLY INCLUDE THE FIELDS YOU WANT TO CLONE
         for (SBQQ__QuoteLineGroup__c qlg : [Select Id, Name, SBQQ__Account__c, SBQQ__AdditionalDiscountRate__c, CPQ_Asset__c, SBQQ__BillingFrequency__c, CurrencyIsoCode, SBQQ__CustomerTotal__c,
                    SBQQ__Description__c, SBQQ__EndDate__c, SBQQ__Favorite__c, SBQQ__ListTotal__c, SBQQ__MarkupRate__c, SBQQ__NetTotal__c, SBQQ__Number__c, SBQQ__Optional__c, SBQQ__QuoteProcess__c,
                    SBQQ__SeparateContract__c, SBQQ__SolutionGroup__c, SBQQ__Source__c,SBQQ__StartDate__c, SBQQ__SubscriptionTerm__c, CPQ_Support_Level_NA__c, CPQ_Support_Tier__c,
                    CPQ_Support_Tier_NA__c, SBQQ__TargetCustomerAmount__c,CPQ_VAR_INTL__c, SBQQ__Quote__c  From SBQQ__QuoteLineGroup__c WHERE SBQQ__Quote__c = : origQuoteId]) {
            SBQQ__QuoteLineGroup__c newQuoteLineGroup = qlg.clone(false);
            newQuoteLineGroup.SBQQ__Quote__c = clonedQuoteId; 
            quoteLineGroupList.add(newQuoteLineGroup);
        }
        if(quoteLineGroupList.size()>0){
            insert quoteLineGroupList;
        }
        return quoteLineGroupList;
    }

    private static List<Opportunity> getParentOpportunity(String optyId){
        List<opportunity> optyList = new List<Opportunity>(); 
        if(String.isNotBlank(optyId)){
            optyList = [Select Id, Name from Opportunity where Id = : optyId ];
        }   
        return optyList;
    }
    
    private static SBQQ__Quote__c getQuoteDetails(String quoteId){
        SBQQ__Quote__c  quoteRecord  = [Select Id, Name, SBQQ__Opportunity2__c, SBQQ__Status__c, SBQQ__Primary__c, CPQ_Quote_Name__c, ApprovalStatus__c, Reseller_Deal__c from SBQQ__Quote__c WHERE Id = : quoteId Limit 1];
        return quoteRecord;
    }

    private static List<String> getListOfDistributor(){
        List<String> distIdNameList = new List<String>();
        for(Account distributorList : [Select Id, Name from Account WHERE Type = 'Distributor']){
            distIdNameList.add(distributorList.Id + ',' + distributorList.Name);
        }
        return distIdNameList;
    }

    private static List<String> getListOfPartner(){
        List<String> partnerIdNameList = new List<String>();
        for(Account partnerList : [Select Id, Name from Account WHERE Type = 'Reseller']){
            partnerIdNameList.add(partnerList.Id + ','+  partnerList.Name);
        }
        return partnerIdNameList;
    }

    @AuraEnabled
    public static String cloneQuoteAndQLI(Id quoteId, Id accountId, Decimal additionalDiscount){
        ResponseWrapper responseWrapperObj = new ResponseWrapper();
        String returnString;
        Savepoint sp = Database.setSavepoint();
        //try{
            QuoteModel masterQuoteModelObj = readQuote(quoteId);
            System.debug('@@ start masterQuoteModelObj:::  ' + masterQuoteModelObj);
            QuoteModel newQuoteModelObj = createNewQuotefromMasterQuote(masterQuoteModelObj, accountId);
            //ITASMB-3
            SBQQ__Quote__c clonedQuote = newQuoteModelObj.record;
            System.debug('clonedQuote = ' + clonedQuote);
            clonedQuote.CPQ_Quote_Name__c = clonedQuote.Name + ' - ' + clonedQuote.SBQQ__Partner__c;
            update clonedQuote;
            //ITASMB-3
            newQuoteModelObj = createQLIfromMasterQLI(masterQuoteModelObj, newQuoteModelObj, additionalDiscount);
            system.debug('@@@ before Calulate call'+ newQuoteModelObj);
            //system.debug('@@@ before calculateQliUpliftPercent ');
            //calculateQliUpliftPercent(newQuoteModelObj, additionalDiscount);
            calculate(newQuoteModelObj, 'MultiBidCallback');
            //calculateQliUpliftPercent(newQuoteModelObj, additionalDiscount);
            //calculate(newQuoteModelObj, 'MultiBidCallback');
            system.debug('@@@ after Calulate call'+ newQuoteModelObj);
            responseWrapperObj.isSuccess = true;
            responseWrapperObj.message = 'SUCCESS';
            returnString = 'SUCCESS';
        /*} catch(Exception ex){
             responseWrapperObj.isSuccess = false;
             responseWrapperObj.message =ex.getMessage();
             returnString = 'ERROR';
             Database.rollback(sp);
        } */
        system.debug('@@ responseWrapperObj :: ' + responseWrapperObj);
        return returnString;
    }

    public static QuoteModel createNewQuotefromMasterQuote(QuoteModel masterQuoteDetails, Id accountId){
        QuoteModel newQuoteDetails = new QuoteModel();
        newQuoteDetails.record = masterQuoteDetails.record;
                                newQuoteDetails.nextKey =masterQuoteDetails.nextKey;
                                newQuoteDetails.applyAdditionalDiscountLast = masterQuoteDetails.applyAdditionalDiscountLast;
                                newQuoteDetails.applyPartnerDiscountFirst = masterQuoteDetails.applyPartnerDiscountFirst;
                                newQuoteDetails.channelDiscountsOffList = masterQuoteDetails.applyPartnerDiscountFirst;
                                newQuoteDetails.customerTotal = masterQuoteDetails.customerTotal;
                                newQuoteDetails.netTotal = masterQuoteDetails.netTotal;
                                newQuoteDetails.netNonSegmentTotal = masterQuoteDetails.netNonSegmentTotal;
        SBQQ__Quote__c sqb = newQuoteDetails.record;
        //sqb.SBQQ__Account__c =  AccountId;
        sqb.MultiBidPrimaryQuote__c = masterQuoteDetails.record.Id;
        sqb.MultiBidPartner__c  = accountId;
        sqb.SBQQ__Primary__c = false;
        SBQQ__Quote__c quoteRecord = getQuoteDetails(masterQuoteDetails.record.Id);
        System.debug('Quote Name :: ' + quoteRecord.CPQ_Quote_Name__c);
        sqb.CPQ_Quote_Name__c = quoteRecord.CPQ_Quote_Name__c;
        sqb.ApprovalStatus__c = quoteRecord.ApprovalStatus__c;
        sqb.Reseller_Deal__c = quoteRecord.Reseller_Deal__c;
        //sqb.MultiBidPrimaryQuote__c = false;
        sqb.Id = null;
        newQuoteDetails.record = sqb;
        QuoteModel quoteDetails = save(newQuoteDetails);
        return quoteDetails;
    }

    public static QuoteModel createQLIfromMasterQLI(QuoteModel masterQuoteDetails,QuoteModel newQuoteDetails, Decimal additionalDiscount){
        System.debug('@@ masterQuoteDetails:::  ' + masterQuoteDetails);
        List<QuoteLineModel> qliModelList = masterQuoteDetails.lineItems;
        List<QuoteLineGroupModel> qliGroupModelList = masterQuoteDetails.lineItemGroups;
        SBQQ__Quote__c newQuoteObj = newQuoteDetails.record;
        System.debug('@@ quote Id :::  ' + newQuoteObj.id);
        System.debug('@@ qliModelList :::  ' + qliModelList);
        if(!qliModelList.isEmpty()){
            createQLIList(qliModelList,(Id)newQuoteObj.id, additionalDiscount);
            newQuoteDetails.lineItems = qliModelList;
            newQuoteDetails.lineItemGroups = qliGroupModelList;
            System.debug('@@ before  save qli :: : ' + newQuoteDetails);
            // Quote Group
            createQLIGroup(qliGroupModelList, (Id)newQuoteObj.id);
            System.debug('@@ before Quote save newQuoteDetails:: : ' + newQuoteDetails);
            newQuoteDetails = save(newQuoteDetails);
            System.debug('@@ after Quote save newQuoteDetails:: : ' + newQuoteDetails);
        }
        return newQuoteDetails;
    }

    public static SObject copyQliValues(sObject masterQLI){
        Set<String> qliFieldSet = getEditableFields('SBQQ__QuoteLine__c');
        SObject sObj = Schema.GetGlobalDescribe().get('SBQQ__QuoteLine__c').newSObject();
        for(String fieldName : qliFieldSet){
            if(fieldName != 'SBQQ__Quote__c'){
                if(masterQLI.get(fieldName) != null){
                   sObj.put(fieldName, masterQLI.get(fieldName));
                }
            }
        }
        sObj.id = null;
        return sObj;
    }

    public static void createQLIGroup(List<QuoteLineGroupModel> qliGroupModelList, Id quoteId){
        if(!qliGroupModelList.isEmpty()){
            for(QuoteLineGroupModel QuoteLineGroupModel : qliGroupModelList){
                            sObject newQliGroupObj = copyQliGroupValues(QuoteLineGroupModel.Record);
                newQliGroupObj.Id = null;
                newQliGroupObj.put('SBQQ__Quote__c',quoteId);
                QuoteLineGroupModel.Record = (SBQQ__QuoteLineGroup__c) newQliGroupObj;
            }
        }
    }

    public static SObject copyQliGroupValues(sObject masterQLIGroup){
        Set<String> qliGroupFieldSet = getEditableFields('SBQQ__QuoteLineGroup__c');
        SObject sObj = Schema.GetGlobalDescribe().get('SBQQ__QuoteLineGroup__c').newSObject();
        for(String fieldName : qliGroupFieldSet){
            if(fieldName != 'SBQQ__Quote__c'){
                if(masterQLIGroup.get(fieldName) != null){
                    sObj.put(fieldName, masterQLIGroup.get(fieldName));
                }
            }
        }
        sObj.id = null;
        return sObj;
    }


    public static Set<String> getEditableFields(String objectName){
        Set<String> editableFieldSet = new Set<String>();
        SObject sObj = Schema.GetGlobalDescribe().get(objectName).newSObject();
        Map<String, Schema.SobjectField> fields = sObj.getSObjectType().getDescribe().fields.getMap();
        for(String fieldName :fields.keySet()){
            DescribeFieldResult fieldDescription = fields.get(fieldName).getDescribe();
            if(fieldDescription.isUpdateable()){
                editableFieldSet.add(fieldDescription.getName());
            }
        }
        return editableFieldSet; 
    }

    public static void createQLIList(List<QuoteLineModel> qliModelList, Id quoteId, Decimal additionalDiscount){
        if(!qliModelList.isEmpty()){
            for(QuoteLineModel quoteLineModelObj : qliModelList){
                                        sObject newQliObj = copyQliValues(quoteLineModelObj.Record);
                                        newQliObj.Id = null;
                                        newQliObj.put('SBQQ__Quote__c',quoteId);
                /*Decimal existingDiscount = (Decimal)newQliObj.get('CPQ_Additional_Disti_Discount__c');
                if(existingDiscount == null){
                    existingDiscount = 0;
                } 
                System.debug('additional discount :: ' + additionalDiscount);
                System.debug('new discount rate :: ' + (existingDiscount - (additionalDiscount*100)));*/
                //newQliObj.put('CPQ_Additional_Disti_Discount__c', (existingDiscount - additionalDiscount*100)); 
                //System.debug('@@@ Uplift_Multi_bid__c :: ' + additionalDiscount);
                //System.debug('@@@ Uplift_Multi_bid__c with 100 :: ' + (additionalDiscount*100));
                newQliObj.put('Uplift_Multi_bid__c',(additionalDiscount*100));
                // calculateUpliftDiscount(newQliObj);
                quoteLineModelObj.Record = (SBQQ__QuoteLine__c) newQliObj;
            }
        }
    }

    public static QuoteModel save(QuoteModel quote) {
        String quoteJSON = SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver',
        JSON.serialize(quote));
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }

    public static void calculate(QuoteModel quote, String callbackClass) {
        QuoteCalculatorContext ctx = new QuoteCalculatorContext(quote, callbackClass);
        SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', null, JSON.serialize(ctx));    
    }

    public static QuoteModel readQuote(Id quoteId){
        QuoteReader reader = new QuoteReader();
        QuoteModel masterQuoteDetails = reader.read(quoteId);
        System.debug('@@ readQuote :: : ' + masterQuoteDetails);
        return masterQuoteDetails;
    }
    
    

    private class QuoteCalculatorContext {        
        private QuoteModel quote;             //The quote and callbackClass properties are called in the API code by the exact names seen here.
        private String callbackClass;         //Altering these property names will cause calculator API calls to fail.
    
        private QuoteCalculatorContext(QuoteModel quote, String callbackClass) {
          this.quote = quote;            
          this.callbackClass = callbackClass;        
        }
    } 
   
    public class ResponseWrapper {        
        public Boolean isSuccess;            
        public String message;         
            
        /*private ResponseWrapper(Boolean isSucess, String message) {
        this.quote = quote;            
        this.callbackClass = callbackClass;        
        }*/
    } 


}