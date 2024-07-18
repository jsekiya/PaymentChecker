global with sharing class CheckerScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        CheckPaymentBatch batch = new CheckPaymentBatch();
        Database.executeBatch(batch);
    }
}