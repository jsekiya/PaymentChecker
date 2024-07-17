global with sharing class CheckPaymentBatch implements 
Database.Batchable<SObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT Id, IsPaid__c, CloseDate, ReminderSentDate__c, Name, StageName, AccountId
            FROM Opportunity 
            WHERE IsPaid__c = false AND StageName = 'Closed Won'
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
            SELECT OpportunityId, Contact.Email, Contact.Name
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

            if(Date.today() > opp.CloseDate.addDays(30) && opp.ReminderSentDate__c == null){
                if(opportunityToEmailMap.containsKey(opp.Id)){
                    String contactEmail = opportunityToEmailMap.get(opp.Id);
                    System.debug('Sending email to: '+ contactEmail);

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[]{contactEmail});
                    mail.setSubject('お支払いのリマインダー');
                    mail.setPlainTextBody('請求書' + opp.Name + 'の支払いを' + Date.today().addDays(7) + 'までにお願いいたします。');
                    emails.add(mail);
                    //aktualizowanie daty wyslania przypomnienia
                    opp.ReminderSentDate__c = Date.today();
                    System.debug('zaktualizowany ReminderSentDate__c : '+ opp.ReminderSentDate__c);
                }  
            }else if(opp.ReminderSentDate__c != null && opp.ReminderSentDate__c.addDays(7) < Date.today()){
                Case newCase = new Case();
                newCase.Subject = '未払いの請求書';
                newCase.Description = '商談' + opp.Name + 'の請求書が支払われていません。';
                newCase.Status = 'New';
                newCase.AccountId = opp.AccountId;
                newCase.ContactId = Contact.Name;
                cases.add(newCase);
                System.debug('Created Case for Opportunity: ' + opp.Id);
            }
        }
        if (!emails.isEmpty()){
            Messaging.sendEmail(emails);
        }
        if (!cases.isEmpty()){
            insert cases;
        }
    
        System.debug('Before update: '+ scope);
        update scope;
        System.debug('After update: '+ scope);
    }
    global void finish(Database.BatchableContext BC){

    }
}