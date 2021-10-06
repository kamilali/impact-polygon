import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";

import { impactNFTAddress, impactMarketAddress } from "../config";

import ImpactNFT from '../artifacts/contracts/ImpactNFT.sol/ImpactNFT.json';
import ImpactMarket from '../artifacts/contracts/ImpactMarket.sol/ImpactMarket.json';

export default function Creator() {
    const [creatorNFTs, setCreatorNFTs] = useState([]);
    const [soldNFTs, setSoldNFTs] = useState([]);

    const [loadingState, setLoadingState] = useState(true);
    
    useEffect(() => {
        loadCreatorNFTs();
    });
    
    async function loadCreatorNFTs() {
        setLoadingState(true);
        const web3Modal = new Web3Modal();
        const connection = await web3Modal.connect()
        const provider = new ethers.providers.Web3Provider(connection);
        const signer = provider.getSigner();

        const tokenContract = new ethers.Contract(impactNFTAddress, ImpactNFT.abi, provider);
        const marketContract = new ethers.Contract(impactMarketAddress, ImpactMarket.abi, signer);
        const data = await marketContract.fetchUserCreatedNFTs();
        
        const items = await Promise.all(data.map(async (item) => {
            const tokenUri = await tokenContract.tokenURI(item.tokenId);
            const meta = await axios.get(tokenUri);
            let price = ethers.utils.formatUnits(item.price.toString(), 'ether');
            let nftItem = {
                price,
                tokenId: item.tokenId.toNumber(),
                seller: item.seller,
                owner: item.owner,
                sold: item.sold,
                image: meta.data.image,
                name: meta.data.name,
                description: meta.data.description
            };
            return nftItem;
        }));
        const sold_items = items.filter(item => item.sold);
        setSoldNFTs(sold_items);
        setCreatorNFTs(items);
        setLoadingState(false);
    }

    return (
        <div>
            <div className="p-4">
                <h2 className="text-2xl py-2">Impact NFTs Created</h2>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
                {
                    creatorNFTs.map((creatorNFT, idx) => (
                    <div key={idx} className="border shadow rounded-xl overflow-hidden">
                        <img src={creatorNFT.image} className="rounded" />
                        <div className="p-4 bg-black">
                        <p className="text-2xl font-bold text-white">{creatorNFT.price} MATIC</p>
                        </div>
                    </div>
                    ))
                }
                </div>
            </div>
            <div className="px-4">
                {
                Boolean(soldNFTs.length) && (
                    <div>
                    <h2 className="text-2xl py-2">Impact NFTs Sold</h2>
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
                        {
                        soldNFTs.map((soldNFT, idx) => (
                            <div key={idx} className="border shadow rounded-xl overflow-hidden">
                                <img src={soldNFT.image} className="rounded" />
                                <div className="p-4 bg-black">
                                    <p className="text-2xl font-bold text-white">{soldNFT.price} MATIC</p>
                                </div>
                            </div>
                        ))
                        }
                    </div>
                    </div>
                )
                }
            </div>
        </div>
    )

}