import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts        from '@salesforce/apex/B2CCatalogController.getProducts';
import getOriginValues    from '@salesforce/apex/B2CCatalogController.getOriginValues';
import getCategoryValues  from '@salesforce/apex/B2CCatalogController.getCategoryValues';
import createWonOpportunity from '@salesforce/apex/B2CCatalogController.createWonOpportunity';

const PAGE_SIZE = 5;
const USD = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
const fmt = v => (v != null ? USD.format(v) : '—');

// Inline SVG Icon Data URI to render when DisplayUrl is null/blank
const PLACEHOLDER_ICON = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='80' height='80' fill='%23919EAB'%3E%3Cpath d='M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14zm-5.04-6.71l-2.75 3.54-1.96-2.36L6.5 17h11l-3.54-4.71zM11.5 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z'/%3E%3C/svg%3E";

const isGenRT = rt => rt && rt.toLowerCase().includes('generator');

export default class B2cCatalog extends LightningElement {
    @api recordId;

    selectedCategory = '';
    selectedCountry  = '';
    opportunityName  = '';
    currentPage      = 1;
    countryOptions   = [];
    categoryOptions  = [];
    error;

    _allProducts = [];
    @track _rowState = {};

    @wire(getOriginValues)
    wiredOrigins({ data }) {
        if (data) {
            this.countryOptions = [
                { label: 'All', value: '' },
                ...data.map(v => ({ label: v, value: v }))
            ];
        }
    }

    @wire(getCategoryValues)
    wiredCategories({ data }) {
        if (data) {
            this._buildCategoryOptions(data);
        }
    }

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

    get totalPages()  { return Math.max(1, Math.ceil(this._allProducts.length / PAGE_SIZE)); }
    get isFirstPage() { return this.currentPage <= 1; }
    get isLastPage()  { return this.currentPage >= this.totalPages; }
    get hasProducts() { return this._allProducts.length > 0; }

    prevPage() { if (!this.isFirstPage) this.currentPage -= 1; }
    nextPage() { if (!this.isLastPage)  this.currentPage += 1; }

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
                    // Uses DisplayUrl value from Apex wrapper, or falls back to SVG
                    imageUrl:       p.imageUrl ? p.imageUrl : PLACEHOLDER_ICON,
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

    handleCategoryChange(e) {
        this.selectedCategory = e.currentTarget.dataset.val;
        this.currentPage = 1;
        this._refreshCategoryOptions();
    }

    handleCountryChange(e) {
        this.selectedCountry = e.detail.value;
        this.currentPage = 1;
    }

    handleOppNameChange(e) { 
        this.opportunityName = e.target.value; 
    }

    toggleDetails(e) {
        const id = e.currentTarget.dataset.id;
        const st = this._rowState[id] || {};
        this._rowState = { ...this._rowState, [id]: { ...st, expanded: !st.expanded } };
    }

    toggleSelect(e) {
        const id = e.currentTarget.dataset.id;
        const st = this._rowState[id] || {};
        this._rowState = { ...this._rowState, [id]: { ...st, selected: !st.selected } };
    }

    get selectedItems() {
        return this._allProducts
            .filter(p => this._rowState[p.pricebookEntryId]?.selected)
            .map(p => ({ ...p, formattedPrice: fmt(p.unitPrice) }));
    }
    
    get hasSelectedItems() { 
        return this.selectedItems.length > 0; 
    }

    get formattedTotal() {
        return fmt(this.selectedItems.reduce((s, i) => s + (i.unitPrice || 0), 0));
    }

    async createOpportunity() {
        if (!this.hasSelectedItems) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No items selected', 
                message: 'Please select at least one product.', 
                variant: 'warning'
            }));
            return;
        }
        try {
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
                title: 'Success', 
                message: 'Won Opportunity created successfully.', 
                variant: 'success'
            }));
            
            this._rowState = {};
            this.opportunityName = '';
        } catch (err) {
            let msg = 'Failed to create opportunity.';
            if (err?.body?.message) {
                msg = err.body.message;
            } else if (err?.message) {
                msg = err.message;
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error', 
                message: msg, 
                variant: 'error'
            }));
        }
    }
}