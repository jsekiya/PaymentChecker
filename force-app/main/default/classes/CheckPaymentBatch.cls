global with sharing class CheckPaymentBatch implements 
Database.Batchable<SObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT Id, IsPaid__c, CloseDate, ReminderSentDate__c
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
            if(Date.today()> opp.CloseDate.addDays(30) && opp.ReminderSentDate__c == null){
                if(opportunityToEmailMap.containsKey(opp.Id)){
                    String contactEmail = opportunityToEmailMap.get(opp.Id);

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[]{contactEmail});
                    mail.setSubject('Przypomnienie o platnosci');
                    mail.setPlainTextBody('Prosze o oplacenie faktury');
                    emails.add(mail);
                    //aktualizowanie daty wyslania przypomnienia
                    opp.ReminderSentDate__c = Date.today();
                }  
            }else if(opp.ReminderSentDate__c != null && Date.today() > opp.ReminderSentDate__c.addDays(7)){
                Case newCase = new Case();
                newCase.Subject = 'Niezaplacona faktura';
                newCase.Description = 'Faktura dla szansy ' + opp.Id + 'nie zostala oplacona.';
                newCase.Status = 'New';

                cases.add(newCase);
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