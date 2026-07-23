import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import LEAD_WEBSITE from '@salesforce/schema/Lead.Website';
import enrichAndSaveAccount from '@salesforce/apex/CompanyEnrichmentController.enrichAndSaveAccount';

/** Headless Lead-page worker that periodically refreshes external company data. */
export default class InvisibleEnrichment extends LightningElement {
    @api recordId;
    _refreshInterval;

    // The reactive wire starts synchronization once the current Lead Website is available.
    @wire(getRecord, { recordId: '$recordId', fields: [LEAD_WEBSITE] })
    wiredLead({ data }) {
        if (data) {
            const rawWebsite = getFieldValue(data, LEAD_WEBSITE);
            if (rawWebsite) {
                const domain = rawWebsite.replace(/^(?:https?:\/\/)?(?:www\.)?/i, "").split('/')[0];
                this.startBackgroundSync(domain);
            }
        }
    }

    startBackgroundSync(domain) {
        if (this._refreshInterval) clearInterval(this._refreshInterval);

        // Run immediately when page opens
        this.runSync(domain);

        // Run every 30 seconds
        this._refreshInterval = setInterval(() => {
            this.runSync(domain);
        }, 30000);
    }

    disconnectedCallback() {
        if (this._refreshInterval) {
            clearInterval(this._refreshInterval);
        }
    }

    async runSync(domain) {
        try {
            // Refresh Lightning Data Service after Apex changes the backing record.
            await enrichAndSaveAccount({ accountId: this.recordId, websiteDomain: domain });
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            console.error('Background enrichment error:', error);
        }
    }
}
