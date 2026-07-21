import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts        from '@salesforce/apex/B2CCatalogController.getProducts';
import getOriginValues    from '@salesforce/apex/B2CCatalogController.getOriginValues';
import getCategoryValues  from '@salesforce/apex/B2CCatalogController.getCategoryValues';
import createWonOpportunity from '@salesforce/apex/B2CCatalogController.createWonOpportunity';

const PAGE_SIZE = 5;
const USD = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
const fmt = v => (v != null ? USD.format(v) : '—');

// True when the Product2 RecordType DeveloperName indicates a Generator
const isGenRT = rt => rt && rt.toLowerCase().includes('generator');

export default class B2cCatalog extends LightningElement {
    @api recordId;

    selectedCategory = '';
    selectedCountry  = '';
    opportunityName  = '';
    currentPage      = 1;
    countryOptions   = [];
    categoryOptions  = [];  // [{ label, value, btnClass }]
    error;

    // source records — never mutated after wire
    _allProducts = [];
    // per-row UI state keyed by pricebookEntryId: { expanded, selected }
    // @track so nested mutations trigger re-render
    @track _rowState = {};

    // ── wire: country picklist ──────────────────────────────────────────────
    @wire(getOriginValues)
    wiredOrigins({ data }) {
        if (data) {
            this.countryOptions = [
                { label: 'All', value: '' },
                ...data.map(v => ({ label: v, value: v }))
            ];
        }
    }

    // ── wire: category picklist (drives filter pills dynamically) ───────────
    @wire(getCategoryValues)
    wiredCategories({ data }) {
        if (data) {
            this._buildCategoryOptions(data);
        }
    }

    // developerName → human label: 'Generator_Product' → 'Generator Product'
    _rtLabel(devName) {
        return devName.replace(/_/g, ' ');
    }

    _buildCategoryOptions(devNames) {
        const all = [{ label: 'All', value: '', btnClass: this._pillClass('') }];
        const options = devNames.map(n => ({
            label: this._rtLabel(n),
            value: n,
            btnClass: this._pillClass(n)
        }));
        this.categoryOptions = [...all, ...options];
    }

    _pillClass(val) {
        return 'pill' + (this.selectedCategory === val ? ' pill-active' : '');
    }

    _refreshCategoryOptions() {
        this.categoryOptions = this.categoryOptions.map(o => ({
            ...o,
            btnClass: this._pillClass(o.value)
        }));
    }

    // ── wire: products ──────────────────────────────────────────────────────
    @wire(getProducts, {
        searchKey:      '',
        categoryFilter: '$selectedCategory',
        countryFilter:  '$selectedCountry'
    })
    wiredProducts({ data, error }) {
        if (data) {
            this._allProducts = data;
            this.error = undefined;
            this.currentPage = 1;
        } else if (error) {
            this.error = error;
            this._allProducts = [];
        }
    }

    // ── pagination ──────────────────────────────────────────────────────────
    get totalPages()  { return Math.max(1, Math.ceil(this._allProducts.length / PAGE_SIZE)); }
    get isFirstPage() { return this.currentPage <= 1; }
    get isLastPage()  { return this.currentPage >= this.totalPages; }
    get hasProducts() { return this._allProducts.length > 0; }

    prevPage() { if (!this.isFirstPage) this.currentPage -= 1; }
    nextPage() { if (!this.isLastPage)  this.currentPage += 1; }

    // ── decorated page slice ────────────────────────────────────────────────
    get pagedProducts() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this._allProducts
            .slice(start, start + PAGE_SIZE)
            .map(p => {
                const st       = this._rowState[p.pricebookEntryId] || {};
                const expanded = !!st.expanded;
                const selected = !!st.selected;
                const isGen    = isGenRT(p.recordTypeName);
                return {
                    ...p,
                    isGenerator:    isGen,
                    isPart:         !isGen,
                    detailKey:      p.pricebookEntryId + '_d',
                    rowClass:       'trow' + (selected ? ' trow-selected' : ''),
                    detailRowClass: 'detail-tr' + (expanded ? ' detail-tr-open' : ''),
                    nameBtnClass:   'name-btn' + (expanded ? ' name-btn-open' : ''),
                    chevron:        expanded ? '▼' : '▶',
                    badgeClass:     'badge ' + (isGen ? 'badge-gen' : 'badge-part'),
                    selectBtnClass: 'sel-btn' + (selected ? ' sel-btn-active' : ''),
                    buttonLabel:    selected ? 'Selected ✓' : 'Select',
                    formattedPrice: fmt(p.unitPrice),
                    avgLife:        p.averageLifeExpectancy != null ? p.averageLifeExpectancy + ' yrs' : '—',
                    weightKg:       p.weight != null ? p.weight + ' kg' : '—',
                    kva:            p.powerGeneratedKva != null ? p.powerGeneratedKva + ' KVA' : '—'
                };
            });
    }

    // ── event handlers ──────────────────────────────────────────────────────
    handleCategoryChange(e) {
        this.selectedCategory = e.currentTarget.dataset.val;
        this.currentPage = 1;
        this._refreshCategoryOptions();
    }

    handleCountryChange(e) {
        this.selectedCountry = e.detail.value;
        this.currentPage = 1;
    }

    handleOppNameChange(e) { this.opportunityName = e.target.value; }

    // click product name → toggle detail row
    toggleDetails(e) {
        const id = e.currentTarget.dataset.id;
        const st = this._rowState[id] || {};
        this._rowState = { ...this._rowState, [id]: { ...st, expanded: !st.expanded } };
    }

    // click Select → toggle selection (qty always 1)
    toggleSelect(e) {
        const id = e.currentTarget.dataset.id;
        const st = this._rowState[id] || {};
        this._rowState = { ...this._rowState, [id]: { ...st, selected: !st.selected } };
    }

    // ── selected items (persists across page / filter changes) ─────────────
    get selectedItems() {
        // search ALL products (not just current page) for selections
        return this._allProducts
            .filter(p => this._rowState[p.pricebookEntryId]?.selected)
            .map(p => ({ ...p, formattedPrice: fmt(p.unitPrice) }));
    }
    get hasSelectedItems() { return this.selectedItems.length > 0; }

    get formattedTotal() {
        return fmt(this.selectedItems.reduce((s, i) => s + (i.unitPrice || 0), 0));
    }

   async createOpportunity() {
        if (!this.hasSelectedItems) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No items selected', message: 'Please select at least one product.', variant: 'warning'
            }));
            return;
        }
        try {
            // Fix: Clean, direct assignment without the problematic JSON serialization layer
            const items = this.selectedItems.map(i => ({
                pricebookEntryId: i.pricebookEntryId,
                unitPrice:        i.unitPrice,
                quantity:         1
            }));

            await createWonOpportunity({
                accountId:       this.recordId,
                opportunityName: this.opportunityName || 'B2C Sale',
                items
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success', message: 'Won Opportunity created successfully.', variant: 'success'
            }));
            
            // reset selections and name
            this._rowState = {};
            this.opportunityName = '';
        } catch (err) {
            let msg = 'Failed to create opportunity.';
            if (err) {
                if (err.body) {
                    if (err.body.message) {
                        msg = err.body.message;
                    } else if (err.body.pageErrors && err.body.pageErrors.length > 0) {
                        msg = err.body.pageErrors[0].message;
                    } else if (err.body.fieldErrors && Object.keys(err.body.fieldErrors).length > 0) {
                        const firstField = Object.keys(err.body.fieldErrors)[0];
                        msg = err.body.fieldErrors[firstField][0].message;
                    }
                } else if (err.message) {
                    msg = err.message;
                }
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error', message: msg, variant: 'error'
            }));
        }
    }
}
