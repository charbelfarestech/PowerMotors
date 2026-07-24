import { LightningElement, api } from 'lwc';

export default class B2cProductDetailModal extends LightningElement {
    // Accepts the selectedProductDetail object from the parent
    @api product;

    // Tells the parent to close the modal
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}