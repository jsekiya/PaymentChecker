global with sharing class CheckPaymentBatch implements Database.Batchable<SObject>, Database.Stateful {
    private List<String> emailDetails = new List<String>();
    private List<String> caseDetails = new List<String>();

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

        Map<Id, OpportunityContactRole> opportunityToContactRoleMap = new Map<Id, OpportunityContactRole>();
        for(OpportunityContactRole ocr : [
            SELECT OpportunityId, Contact.Email, Contact.Name
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds
        ]){
            opportunityToContactRoleMap.put(ocr.OpportunityId, ocr);
        }

        for (Opportunity opp : scope){
            if(Date.today() > opp.CloseDate.addDays(30) && opp.ReminderSentDate__c == null){
                if(opportunityToContactRoleMap.containsKey(opp.Id)){
                    OpportunityContactRole contactRole = opportunityToContactRoleMap.get(opp.Id);
                    String contactEmail = contactRole.Contact.Email;

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[]{contactEmail});
                    mail.setSubject('お支払いのリマインダー');
                    mail.setPlainTextBody('請求書' + opp.Name + 'の支払いを' + Date.today().addDays(7) + 'までにお願いいたします。');
                    emails.add(mail);
                    opp.ReminderSentDate__c = Date.today();

                    //for administrator report
                    emailDetails.add('顧客：' + contactRole.Contact.Name + '、商談：' + opp.Name + '\n');
                }
            }else if(opp.ReminderSentDate__c != null && opp.ReminderSentDate__c.addDays(7) == Date.today()){
                OpportunityContactRole contactRole = opportunityToContactRoleMap.get(opp.Id);
                Case newCase = new Case();
                newCase.Subject = '未払いの請求書';
                newCase.Description = '商談' + opp.Name + 'の請求書が支払われていません。';
                newCase.Status = 'New';
                newCase.AccountId = opp.AccountId;
                newCase.ContactId = contactRole.Contact.Id;
                cases.add(newCase);

                //for administrator report
                caseDetails.add('商談：' + opp.Name + '、顧客：' + contactRole.Contact.Name + '\n');
            }
        }
        if (!emails.isEmpty()){
            Messaging.sendEmail(emails);
        }
        if (!cases.isEmpty()){
            insert cases;
        }
        update scope;
    }
    global void finish(Database.BatchableContext BC){
        User sysAdmin = [SELECT Id, Email FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        String adminEmail = sysAdmin.Email;

        String emailBody = 'CheckPaymentBatchバッチ実行レポート： \n\n'+
                            '送信された顧客情報：\n' + String.join(emailDetails, '\n') +
                            '作成されたケースの詳細：\n' + String.join(caseDetails, '\n');

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{adminEmail});
        mail.setSubject('CheckPaymentBatchバッチ実行サマリー');
        mail.setPlainTextBody(emailBody);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
    }
}