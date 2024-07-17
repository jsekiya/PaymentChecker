global with sharing class CheckPaymentBatch implements 
Database.Batchable<SObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT Id, IsPaid__c, CloseDate, ReminderSentDate__c, Name
            FROM Opportunity 
            WHERE IsPaid__c = false
        ]);
    }
    public void execute(Database.BatchableContext BC, List<Opportunity> scope){
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Case> cases = new List<Case>();

        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : scope){
            opportunityIds.add(opp.Id);
        }

        Map<Id, String> opportunityToEmailMap = new Map<Id, String>();
        for(OpportunityContactRole ocr : [
            SELECT OpportunityId, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds
        ]){
            opportunityToEmailMap.put(ocr.OpportunityId, ocr.Contact.Email);
        }

        for (Opportunity opp : scope){
            System.debug('Processing Opportunity: ' + opp.Id);
            System.debug('CLoseDate: ' + opp.CloseDate);
            System.debug('ReminderSentDate__c: ' + opp.ReminderSentDate__c);
            System.debug('Date.today(): ' + Date.today());

            if(Date.today()> opp.CloseDate.addDays(30) && opp.ReminderSentDate__c == null){
                if(opportunityToEmailMap.containsKey(opp.Id)){
                    String contactEmail = opportunityToEmailMap.get(opp.Id);
                    System.debug('Sending email to: '+ contactEmail);

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[]{contactEmail});
                    mail.setSubject('Przypomnienie o platnosci');
                    mail.setPlainTextBody('Prosze o oplacenie faktury ' + opp.Name + ' do terminu:' + Date.today().addDays(7));
                    emails.add(mail);
                    //aktualizowanie daty wyslania przypomnienia
                    opp.ReminderSentDate__c = Date.today();
                }  
            }
        }
        if (!emails.isEmpty()){
            Messaging.sendEmail(emails);
        }
    
        update scope;
    }
    global void finish(Database.BatchableContext BC){

    }
}