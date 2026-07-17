import { LightningElement, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts from '@salesforce/apex/B2CCatalogController.getProducts';
import getCategoryValues from '@salesforce/apex/B2CCatalogController.getCategoryValues';
import getOriginValues from '@salesforce/apex/B2CCatalogController.getOriginValues';
import createWonOpportunity from '@salesforce/apex/B2CCatalogController.createWonOpportunity';

export default class b2cCatalog extends LightningElement {
    @api recordId;
    searchKey = '';
    selectedCategory = '';
    selectedCountry = '';
    opportunityName = '';
    products = [];
    categoryOptions = [];
    countryOptions = [];
    selectedProduct = null;
    selectedItems = [];
    error;

    @wire(getCategoryValues) wiredCategories({ data }) {
        if (data) this.categoryOptions = [{ label: 'All', value: '' }, ...data.map(v => ({ label: v, value: v }))];
    }
    @wire(getOriginValues) wiredOrigins({ data }) {
        if (data) this.countryOptions = [{ label: 'All', value: '' }, ...data.map(v => ({ label: v, value: v }))];
    }
    @wire(getProducts, { searchKey: '$searchKey', categoryFilter: '$selectedCategory', countryFilter: '$selectedCountry' })
    wiredProducts({ data, error }) {
        if (data) {
            this.products = data.map(p => ({ ...p, quantity: 1, selected: false, buttonLabel: 'Select', buttonVariant: 'neutral', cardClass: 'card' }));
            this.error = undefined;
            if (!this.selectedProduct && this.products.length) this.selectedProduct = this.products[0];
        } else if (error) {
            this.error = error;
            this.products = [];
        }
    }
    handleSearch(e) { this.searchKey = e.target.value; }
    handleCategoryChange(e) { this.selectedCategory = e.detail.value; }
    handleCountryChange(e) { this.selectedCountry = e.detail.value; }
    handleOppNameChange(e) { this.opportunityName = e.target.value; }
    handleQtyChange(e) {
        const id = e.target.dataset.id;
        const qty = parseInt(e.target.value, 10) || 1;
        this.products = this.products.map(p => p.pricebookEntryId === id ? { ...p, quantity: qty } : p);
        this.selectedItems = this.selectedItems.map(i => i.pricebookEntryId === id ? { ...i, quantity: qty } : i);
    }
    toggleSelect(e) {
        const id = e.target.dataset.id;
        const product = this.products.find(p => p.pricebookEntryId === id);
        if (!product) return;
        const exists = this.selectedItems.some(i => i.pricebookEntryId === id);
        if (exists) this.selectedItems = this.selectedItems.filter(i => i.pricebookEntryId !== id);
        else this.selectedItems = [...this.selectedItems, { pricebookEntryId: id, unitPrice: product.unitPrice, quantity: product.quantity, name: product.name }];
        this.products = this.products.map(p => p.pricebookEntryId === id ? { ...p, selected: !exists, buttonLabel: exists ? 'Select' : 'Selected', buttonVariant: exists ? 'neutral' : 'brand', cardClass: exists ? 'card' : 'card selected' } : p);
    }
    openDetails(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedProduct = this.products.find(p => p.pricebookEntryId === id) || null;
    }
    get hasProducts() { return this.products.length > 0; }
    get selectedTotal() { return this.selectedItems.reduce((sum, i) => sum + (Number(i.unitPrice) * Number(i.quantity || 1)), 0); }
    async createOpportunity() {
        try {
            const oppId = await createWonOpportunity({ accountId: this.recordId, opportunityName: this.opportunityName, items: this.selectedItems });
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Won Opportunity created', variant: 'success' }));
            this.selectedItems = [];
            this.products = this.products.map(p => ({ ...p, selected: false, buttonLabel: 'Select', buttonVariant: 'neutral', cardClass: 'card' }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: e?.body?.message || 'Failed to create opportunity', variant: 'error' }));
        }
    }
}
