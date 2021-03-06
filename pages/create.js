import { useState } from 'react';
import { ethers } from 'ethers';
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { useRouter } from 'next/router';
import Web3Modal from 'web3modal';
import { impactMarketAddress, impactNFTAddress } from '../config';
import ImpactNFT from '../artifacts/contracts/ImpactNFT.sol/ImpactNFT.json';
import ImpactMarket from '../artifacts/contracts/ImpactMarket.sol/ImpactMarket.json';

const ipfsClient = ipfsHttpClient('https://ipfs.infura.io:5001/api/v0');

export default function CreateItem() {
    const [fileUrl, setFileUrl] = useState(null);
    const [formInput, updateFormInput] = useState({price: '', name: '', description: ''});
    const [creating, setCreating] = useState(false);
    const router = useRouter();

    async function onFileChange(e) {
        const file = e.target.files[0];
        try {
            const fileAdded = await ipfsClient.add(
                file,
                {
                    progress: (prog) => console.log(`received: ${prog}`)
                }
            );
            const url = `https://ipfs.infura.io/ipfs/${fileAdded.path}`;
            setFileUrl(url);
        } catch (e) {
            console.log(e);
        }
    }

    async function createItem() {
        setCreating(true);
        const { name, description, price } = formInput;
        if (!name || !description || !price || !fileUrl) {
            return;
        }
        const data = JSON.stringify({
            name, description, image: fileUrl
        });

        try {
            const dataAdded = await ipfsClient.add(data);
            const url = `https://ipfs.infura.io/ipfs/${dataAdded.path}`;
            console.log("file added to ipfs:", url);
            await createSale(url);
            console.log("Created sale");
        } catch (error) {
            console.log('Error uploading file: ', error);
        }
        setCreating(false);
    }

    async function createSale(url) {
        const web3Modal = new Web3Modal();
        const connection = await web3Modal.connect();
        const provider = new ethers.providers.Web3Provider(connection);
        const signer = provider.getSigner();

        const impactNFTContract = new ethers.Contract(impactNFTAddress, ImpactNFT.abi, signer);
        let transaction = await impactNFTContract.createToken(url);
        let tx = await transaction.wait();
        console.log("first tx");

        let event = tx.events[0];
        let value = event.args[2];
        let tokenId = value.toNumber();

        const price = ethers.utils.parseUnits(formInput.price, 'ether');

        const impactMarketContract = new ethers.Contract(impactMarketAddress, ImpactMarket.abi, signer);
        let listingPrice = await impactMarketContract.getListingPrice();
        listingPrice = listingPrice.toString();
        let campaignId = 0; // this should be dynamic and state controlled

        transaction = await impactMarketContract.createMarketItem(impactNFTAddress, tokenId, price, campaignId, { value: listingPrice });
        tx = await transaction.wait();
        console.log("second tx");
        router.push('/');
    }

    return (
        <div className="flex justify-center">
            <div className="w-1/2 flex flex-col pb-12">
                <input 
                    placeholder="Impact NFT Name"
                    className="mt-8 border rounded p-4"
                    onChange={e => updateFormInput({...formInput, name: e.target.value})}
                />
                <textarea 
                    placeholder="Impact NFT Description"
                    className="mt-2 border rounded p-4"
                    onChange={e => updateFormInput({...formInput, description: e.target.value})}
                />
                <input 
                    placeholder="Impact NFT Price (MATIC)"
                    className="mt-2 border rounded p-4"
                    onChange={e => updateFormInput({...formInput, price: e.target.value})}
                />
                <input 
                    type="file"
                    name="ImpactArt"
                    className="my-4"
                    onChange={onFileChange}
                />
                { fileUrl && (<img className="rounded mt-4" width="350" src={fileUrl} />)}
                <button
                    onClick={createItem}
                    disabled={creating}
                    className="font-bold mt-4 bg-pink-500 text-white rounded p-4 shadow-lg"
                >
                    Create Impact Artwork
                </button>
            </div>
        </div>
    )
}