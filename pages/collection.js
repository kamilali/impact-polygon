import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";

import { impactNFTAddress, impactMarketAddress } from "../config";

import ImpactNFT from '../artifacts/contracts/ImpactNFT.sol/ImpactNFT.json';
import ImpactMarket from '../artifacts/contracts/ImpactMarket.sol/ImpactMarket.json';

export default function Collection() {
  const [ownedNFTs, setOwnedNFTs] = useState([]);
  const [loadingState, setLoadingState] = useState(true);

  useEffect(() => {
    loadOwnedNFTs();
  }, []);
  
  async function loadOwnedNFTs() {
    setLoadingState(true);
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    const tokenContract = new ethers.Contract(impactNFTAddress, ImpactNFT.abi, provider);
    const marketContract = new ethers.Contract(impactMarketAddress, ImpactMarket.abi, signer);
    const data = await marketContract.fetchUserOwnedNFTs();
    
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

    setOwnedNFTs(items);
    setLoadingState(false);
  }

  if (!loadingState && ownedNFTs.length == 0) {
    return (
      <h1 className="px-20 py-10 text-3xl">You don't currently own any Impact NFTs.</h1>
    )
  } else if (!loadingState) {
    return (
      <div className="flex justify-center">
        <div className="p-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-4">
            {
              ownedNFTs.map((ownedNFT, idx) => (
                <div key={idx} className="border shadow rounded-xl overflow-hidden">
                  <img src={ownedNFT.image} />
                  <div className="p-4">
                    <p style={{ height: '64px' }} className="text-2xl font-semibold">{ownedNFT.name}</p>
                    <div style={{ height: '70px', overflow: 'hidden' }}>
                      <p className="text-gray-400">{ownedNFT.description}</p>
                    </div>
                  </div>
                  <div className="p-4 bg-black">
                    <p className="text-2xl mb-4 font-bold text-white">{ownedNFT.price} MATIC</p>
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