import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts        from '@salesforce/apex/B2CCatalogController.getProducts';
import getOriginValues    from '@salesforce/apex/B2CCatalogController.getOriginValues';
import getCategoryValues  from '@salesforce/apex/B2CCatalogController.getCategoryValues';
import createWonOpportunity from '@salesforce/apex/B2CCatalogController.createWonOpportunity';

// Display-only constants; server data remains numeric until rendered in the UI.
const PAGE_SIZE = 5;
const USD = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
const fmt = v => (v != null ? USD.format(v) : '—');

const PLACEHOLDER_ICON = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='80' height='80' fill='%23919EAB'%3E%3Cpath d='M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14zm-5.04-6.71l-2.75 3.54-1.96-2.36L6.5 17h11l-3.54-4.71zM11.5 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z'/%3E%3C/svg%3E";

const isGenRT = rt => rt && rt.toLowerCase().includes('generator');

const DATATABLE_COLUMNS = [
    { label: 'Product Name', fieldName: 'name', type: 'text' },
    { label: 'Family', fieldName: 'productFamily', type: 'text' },
    { label: 'Country of Origin', fieldName: 'countryOfOrigin', type: 'text' },
    { 
        label: 'Unit Price', 
        fieldName: 'unitPrice', 
        type: 'currency', 
        typeAttributes: { currencyCode: 'USD' },
        cellAttributes: { alignment: 'right' } 
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Details', name: 'view_details' }
            ]
        }
    }
];

/** Account-page catalog that retains selections across pages and submits a sale to Apex. */
export default class B2cCatalog extends NavigationMixin(LightningElement) {
    @api recordId;

    selectedCategory = '';
    selectedCountry  = '';
    opportunityName  = '';
    currentPage      = 1;
    countryOptions   = [];
    categoryOptions  = [];
    error;

    columns = DATATABLE_COLUMNS;
    _allProducts = [];
    selectedRowIds = []; // Master list of selected PricebookEntry IDs

    // Modal state
    isModalOpen = false;
    selectedProductDetail = null;

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

    // Reactive parameters automatically reload the catalog when either filter changes.
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
        return this._allProducts.slice(start, start + PAGE_SIZE);
    }

    // Only pass IDs to lightning-datatable that exist on the CURRENT page
    get selectedRowsForCurrentPage() {
        const currentPageIds = new Set(this.pagedProducts.map(p => p.pricebookEntryId));
        return this.selectedRowIds.filter(id => currentPageIds.has(id));
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

    // Merge this page's selection with IDs remembered from the other pages.
    handleRowSelection(event) {
        const selectedRowsOnPage = event.detail.selectedRows;
        const selectedIdsOnPage = new Set(selectedRowsOnPage.map(r => r.pricebookEntryId));
        const currentPageIds = new Set(this.pagedProducts.map(p => p.pricebookEntryId));

        // Preserve selections from OTHER pages
        const otherPageSelectedIds = this.selectedRowIds.filter(id => !currentPageIds.has(id));

        // Combine other page selections with current page selections
        this.selectedRowIds = [...otherPageSelectedIds, ...selectedIdsOnPage];
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_details') {
            const isGen = isGenRT(row.recordTypeName);
            // Add presentation-only values without mutating the server row.
            this.selectedProductDetail = {
                ...row,
                imageUrl: row.imageUrl ? row.imageUrl : PLACEHOLDER_ICON,
                isGenerator: isGen,
                isPart: !isGen,
                avgLife: row.averageLifeExpectancy != null ? row.averageLifeExpectancy + ' yrs' : '—',
                weightKg: row.weight != null ? row.weight + ' kg' : '—',
                kva: row.powerGeneratedKva != null ? row.powerGeneratedKva + ' KVA' : '—'
            };
            this.isModalOpen = true;
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedProductDetail = null;
    }

    removeSelectedItem(e) {
        const idToRemove = e.currentTarget.dataset.id;
        this.selectedRowIds = this.selectedRowIds.filter(id => id !== idToRemove);
    }

    get selectedItems() {
        const idSet = new Set(this.selectedRowIds);
        return this._allProducts
            .filter(p => idSet.has(p.pricebookEntryId))
            .map(p => ({ ...p, formattedPrice: fmt(p.unitPrice) }));
    }
    
    get hasSelectedItems() { 
        return this.selectedItems.length > 0; 
    }

    get formattedTotal() {
        return fmt(this.selectedItems.reduce((s, i) => s + (i.unitPrice || 0), 0));
    }

    get isCreateDisabled() {
        return !this.hasSelectedItems || !this.opportunityName || !this.opportunityName.trim();
    }

    async createOpportunity() {
        const inputCmp = this.template.querySelector('.opp-name-input');
        if (inputCmp && !inputCmp.reportValidity()) {
            return;
        }

        if (!this.hasSelectedItems) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No items selected', 
                message: 'Please select at least one product.', 
                variant: 'warning'
            }));
            return;
        }

        try {
            // Convert visible product rows into the Apex SelectedItem contract.
            const items = this.selectedItems.map(i => ({
                pricebookEntryId: i.pricebookEntryId,
                unitPrice:        i.unitPrice,
                quantity:         1
            }));

            // Capture the created Opportunity ID returned by Apex
            const oppId = await createWonOpportunity({
                accountId:       this.recordId,
                opportunityName: this.opportunityName.trim(),
                items
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success', 
                message: 'Won Opportunity created successfully.', 
                variant: 'success'
            }));
            
            this.selectedRowIds = [];
            this.opportunityName = '';

            // Redirect the user to the newly created Opportunity record page
            if (oppId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: oppId,
                        objectApiName: 'Opportunity',
                        actionName: 'view'
                    }
                });
            }
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