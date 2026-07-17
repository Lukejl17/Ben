import Foundation
import Testing
@testable import Ben

struct PaymentDetailsTests {
    @Test func extractsBpayBlockOnOneLine() {
        let details = PaymentDetailsExtractor.extract(from: [
            "AGL Electricity", "Tax Invoice",
            "Biller Code: 93880  Ref: 2043 4455 6677"
        ])
        #expect(details.bpayBillerCode == "93880")
        #expect(details.bpayReference == "204344556677")
        #expect(details.bsb == nil)
    }

    @Test func extractsBpayAcrossLines() {
        let details = PaymentDetailsExtractor.extract(from: [
            "How to pay", "BPAY", "Biller Code:", "93880", "Ref:", "2043 4455 6677"
        ])
        #expect(details.bpayBillerCode == "93880")
        #expect(details.bpayReference == "204344556677")
    }

    @Test func crnFillsBpayReferenceWhenRefLabelMissing() {
        let details = PaymentDetailsExtractor.extract(from: [
            "Biller Code: 93880",
            "Customer Reference Number", "8899 0011 22"
        ])
        #expect(details.bpayReference == "8899001122")
    }

    @Test func extractsEftBlockNearBsb() {
        let details = PaymentDetailsExtractor.extract(from: [
            "Direct deposit",
            "BSB: 062-000",
            "Account Number: 13579246",
            "Reference: 2043 4455 6677"
        ])
        #expect(details.bsb == "062000")
        #expect(details.accountNumber == "13579246")
        #expect(details.eftReference == "204344556677")
    }

    @Test func accountNumberAloneIsNotBankDetails() {
        // "Account number" without a BSB nearby is the customer account.
        let details = PaymentDetailsExtractor.extract(from: [
            "AGL Electricity", "Account Number: 3344 5566",
            "Amount due $243.00", "Due date 24 July 2026"
        ])
        #expect(details.accountNumber == nil)
        #expect(details.bsb == nil)
        #expect(details.isEmpty)
    }

    @Test func plainBillHasNoPaymentDetails() {
        let details = PaymentDetailsExtractor.extract(from: [
            "Sydney Water", "Tax Invoice 100234", "Total $86.50", "Due 12/08/2026"
        ])
        #expect(details.isEmpty)
    }

    @Test func heuristicsPipeCarriesPaymentThrough() {
        let parsed = BillTextHeuristics().extract(from: [
            "AGL", "Amount due $243.00", "Due date 24 July 2026",
            "Biller Code: 93880 Ref: 204344556677"
        ])
        #expect(parsed.payment.bpayBillerCode == "93880")
        #expect(parsed.payment.bpayReference == "204344556677")
    }

    @Test func displayFormattingGroupsDigits() {
        #expect(PaymentDetails.displayBSB("062000") == "062-000")
        #expect(PaymentDetails.displayReference("204344556677") == "2043 4455 6677")
        #expect(PaymentDetails.displayReference("13579246") == "1357 9246")
        #expect(PaymentDetails.displayReference("93880") == "93880")
    }
}
