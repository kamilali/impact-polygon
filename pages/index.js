import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";
import { impactNFTAddress, impactMarketAddress } from "../config";

import ImpactNFT from '../artifacts/contracts/ImpactNFT.sol/ImpactNFT.json';
import ImpactMarket from '../artifacts/contracts/ImpactMarket.sol/ImpactMarket.json';

export default function Home() {

  const [unsoldNFTs, setUnsoldNFTs] = useState([]);
  const [loadingState, setLoadingState] = useState(true);

  useEffect(() => {
    loadUnsoldNFTs();
  }, []);

  async function loadUnsoldNFTs() {
    setLoadingState(true);
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const tokenContract = new ethers.Contract(impactNFTAddress, ImpactNFT.abi, provider);
    const marketContract = new ethers.Contract(impactMarketAddress, ImpactMarket.abi, provider);
    const data = await marketContract.fetchMarketItems();
    
    const items = await Promise.all(data.map(async (item) => {
      const tokenUri = await tokenContract.tokenURI(item.tokenId);
      const meta = await axios.get(tokenUri);
      let price = ethers.utils.formatUnits(item.price.toString(), 'ether');
      let nftItem = {
        price,
        tokenId: item.tokenId.toNumber(),
        seller: item.seller,
        owner: item.owner,
        image: meta.data.image,
        name: meta.data.name,
        description: meta.data.description
      };
      return nftItem;
    }));

    setUnsoldNFTs(items);
    setLoadingState(false);
  }

  async function purchaseNFT(impactNFT) {
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);

    const signer = provider.getSigner();
    const impactMarketContract = new ethers.Contract(impactMarketAddress, ImpactMarket.abi, signer);

    const price = ethers.utils.parseUnits(impactNFT.price.toString(), 'ether');
    const transaction = await impactMarketContract.createMarketSale(impactNFTAddress, impactNFT.tokenId, { value: price });
    await transaction.wait();

    loadUnsoldNFTs();
  }

  if (!loadingState && unsoldNFTs.length == 0) {
    return (
      <h1 className="px-20 py-10 text-3xl">No Impact NFTs are currently available for purchase on the marketplace.</h1>
    )
  } else if (!loadingState) {
    return (
      <div className="flex justify-center">
        <div className="px-4" style={{ maxWidth: '1600px' }}>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
            {
              unsoldNFTs.map((unsoldNFT, idx) => (
                <div key={idx} className="border shadow rounded-xl overflow-hidden">
                  <img src={unsoldNFT.image} />
                  <div className="p-4">
                    <p style={{ height: '64px' }} className="text-2xl font-semibold">{unsoldNFT.name}</p>
                    <div style={{ height: '70px', overflow: 'hidden' }}>
                      <p className="text-gray-400">{unsoldNFT.description}</p>
                    </div>
                  </div>
                  <div className="p-4 bg-black">
                    <p className="text-2xl mb-4 font-bold text-white">{unsoldNFT.price} MATIC</p>
                    <button className="w-full bg-pink-500 text-white font-bold py-2 px-12 rounded" onClick={() => purchaseNFT(unsoldNFT)}>Purchase</button>
                  </div>
                </div> 
              ))
            }
          </div>
        </div>
      </div>
    )
  } else {
    return(
      <h1>Loading...</h1>
    )
  }

  
}
