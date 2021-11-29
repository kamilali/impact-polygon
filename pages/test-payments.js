import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";
const Web3 = require("web3");

import { impactPaymentAddress, impactPaymasterAddress } from "../config";

import ImpactPayment from '../artifacts/contracts/ImpactPayments.sol/ImpactPayments.json';
// import ImpactPaymaster from '../artifacts/contracts/ImpactPaymaster.sol/ImpactPaymaster.json';

const daiTokenAddress = "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa";
const usdcTokenAddress = "0xc2569dd7d0fd715b054fbf16e75b001e5c0c1115";

const WEB3_PROVIDER = 'https://kovan.infura.io/v3/959dde76f6ab4023870800531d390fc6';

// const config = { 
//     paymasterAddress: impactPaymasterAddress,
//     loggerConfiguration: {
//         logLevel: 'debug',
//         // loggerUrl: 'logger.opengsn.org',
//     }
// }

const ERC20ABI = [
  // approve function
  "function approve(address usr, uint wad) external returns (bool)",
]

async function payDaiTest() {
    console.log("Testing DAI payments");
    const expiry = Date.now() + 120;
    const nonce = 1;
    const spender = impactPaymentAddress;

    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    // const paymentContractSigned = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    // const paymasterContractSigned = new ethers.Contract(impactPaymasterAddress, ImpactPaymaster.abi, signer);
    const fromAddress = await signer.getAddress();
    console.log(fromAddress);

    // paymasterContractSigned._depositProceedsToHubPublic("100000000000000000");

    // await paymentContract.methods.testContractFunction(100).send({ from: fromAddress });

    // call permit to allow access for impact payment contract
    // const gsnProvider = await RelayProvider.newProvider({ provider: window.ethereum, config }).init();
    // let newProvider = new ethers.providers.Web3Provider(gsnProvider);
    // let newSigner = newProvider.getSigner();
    const paymentContract = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    
    // var signedData = await signTransferPermit(fromAddress, expiry, nonce, spender);
    // console.log(signedData);
    let daiAmount = "100000000000000000";

    // approve dai (non-gasless)
    const daiContract = new ethers.Contract(daiTokenAddress, ERC20ABI, signer);
    let transaction = await daiContract.approve(impactPaymentAddress, daiAmount);
    let tx = await transaction.wait();

    // let transaction = await paymentContract.permitContractWithdrawals(
    //     daiTokenAddress,signedData.holder, signedData.spender, signedData.nonce,
    //     signedData.expiry, signedData.allowed, signedData.v, signedData.r, signedData.s);
    // let tx = await transaction.wait();
    
    transaction = await paymentContract.depositFunds(0, daiTokenAddress, daiAmount);
    tx = await transaction.wait();
}

async function payUSDCTest() {
    console.log("Testing USDC payments");
    const spender = impactPaymentAddress;

    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    // const paymentContractSigned = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    // const paymasterContractSigned = new ethers.Contract(impactPaymasterAddress, ImpactPaymaster.abi, signer);
    const fromAddress = await signer.getAddress();
    console.log(fromAddress);

    // paymasterContractSigned._depositProceedsToHubPublic("100000000000000000");

    // await paymentContract.methods.testContractFunction(100).send({ from: fromAddress });

    // call permit to allow access for impact payment contract
    // const gsnProvider = await RelayProvider.newProvider({ provider: window.ethereum, config }).init();
    // let newProvider = new ethers.providers.Web3Provider(gsnProvider);
    // let newSigner = newProvider.getSigner();
    const paymentContract = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    
    // var signedData = await signTransferPermit(fromAddress, expiry, nonce, spender);
    // console.log(signedData);
    let usdcAmount = "100000000000000000";

    // approve usdc
    const usdcContract = new ethers.Contract(usdcTokenAddress, ERC20ABI, signer);
    let transaction = await usdcContract.approve(impactPaymentAddress, usdcAmount);
    await transaction.wait();
    
    transaction = await paymentContract.depositFunds(0, usdcTokenAddress, usdcAmount);
    await transaction.wait();
}

async function payETHTest() {
    console.log("Testing ETH payments");

    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    // const paymentContractSigned = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    // const paymasterContractSigned = new ethers.Contract(impactPaymasterAddress, ImpactPaymaster.abi, signer);
    const fromAddress = await signer.getAddress();
    console.log(fromAddress);

    const paymentContract = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    
    let ethAmount = ethers.utils.parseEther("0.01");
    
    let transaction = await paymentContract.depositFundsETH(0, {value: ethAmount});
    console.log(transaction);
    let tx = await transaction.wait();
    console.log(tx);
}

export const signTransferPermit = async function (fromAddress, expiry, nonce, spender) {
    const messageData = createPermitMessageData(fromAddress, spender, nonce, expiry);
    const sig = await signData(web3, fromAddress, messageData.typedData);
    return Object.assign({}, sig, messageData.message);
};

const signData = async function (web3, fromAddress, typeData) {
    return new Promise(function (resolve, reject) {
    web3.currentProvider.sendAsync(
        {
        id: 1,
        method: "eth_signTypedData_v3",
        params: [fromAddress, typeData],
        from: fromAddress,
        },
        function (err, result) {
        if (err) {
            reject(err); //TODO
        } else {
            const r = result.result.slice(0, 66);
            const s = "0x" + result.result.slice(66, 130);
            const v = Number("0x" + result.result.slice(130, 132));
            resolve({
            v,
            r,
            s,
            });
        }
        }
    );
    });
};

const createPermitMessageData = function (fromAddress, spender, nonce, expiry) {
    const message = {
    holder: fromAddress,
    spender: spender,
    nonce: nonce,
    expiry: expiry,
    allowed: true,
    };

    const typedData = JSON.stringify({
    types: {
        EIP712Domain: [
        {
            name: "name",
            type: "string",
        },
        {
            name: "version",
            type: "string",
        },
        {
            name: "chainId",
            type: "uint256",
        },
        {
            name: "verifyingContract",
            type: "address",
        },
        ],
        Permit: [
        {
            name: "holder",
            type: "address",
        },
        {
            name: "spender",
            type: "address",
        },
        {
            name: "nonce",
            type: "uint256",
        },
        {
            name: "expiry",
            type: "uint256",
        },
        {
            name: "allowed",
            type: "bool",
        },
        ],
    },
    primaryType: "Permit",
    domain: {
        name: "Dai Stablecoin",
        version: "1",
        chainId: 42,
        verifyingContract: daiTokenAddress,
    },
    message: message,
    });

    return {
    typedData,
    message,
    };
};

export default function TestPayments() {

    const [loadingState, setLoadingState] = useState(true);
    const [totalFundsETH, setTotalFundsETH] = useState("");

    useEffect(() => {
        setLoadingState(true);
        connectUser();
        getTotalFundsDeposited(0);
        setEventListenersForDeposits(0);
        setLoadingState(false);
    }, []);

    async function connectUser() {
        const web3Modal = new Web3Modal();
        const connection = await web3Modal.connect();
        const provider = new ethers.providers.Web3Provider(connection);
        const signer = provider.getSigner();
        const signerAddress = await signer.getAddress();
    }

    async function getTotalFundsDeposited(campaignId) {
        console.log("Testing ETH payments");

        // const web3Modal = new Web3Modal();
        // const connection = await web3Modal.connect();
        // const provider = new ethers.providers.Web3Provider(connection);

        // const paymentContract = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, provider);
        
        // let totalFunds = await paymentContract.getCampaignFunds(campaignId);
        // let totalFundsETH = ethers.utils.formatEther(totalFunds.toString());
        // setTotalFundsETH(totalFundsETH);
    }

    async function setEventListenersForDeposits(listenCampaignId) {
        const web3Modal = new Web3Modal();
        const connection = await web3Modal.connect();
        const provider = new ethers.providers.Web3Provider(connection);
        const paymentContract = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, provider);
        paymentContract.on("Deposit", (sender, amount, campaignId) => {
            console.log("received deposit event", sender, amount, campaignId);
            if (campaignId == listenCampaignId) {
                getTotalFundsDeposited(campaignId);
            }
        })
    }

    if (!loadingState) {
        return (
            <div>
                <div className="p-4">
                    <h2 className="text-2xl py-2">Impact Payments Testing (DAI)</h2>
                    <button className="w-50 bg-pink-500 text-white font-bold py-2 px-12 rounded" onClick={() => payDaiTest()}>Pay in DAI</button>
                </div>
                <div className="p-4">
                    <h2 className="text-2xl py-2">Impact Payments Testing (USDC)</h2>
                    <button className="w-50 bg-pink-500 text-white font-bold py-2 px-12 rounded" onClick={() => payUSDCTest()}>Pay in USDC</button>
                </div>
                <div className="p-4">
                    <h2 className="text-2xl py-2">Impact Payments Testing (ETH)</h2>
                    <button className="w-50 bg-pink-500 text-white font-bold py-2 px-12 rounded" onClick={() => payETHTest()}>Pay in ETH</button>
                </div>
                {/* <div className="p-4">
                    <h2 className="text-xl py-2">Total Funds: {totalFundsETH} ETH</h2>
                </div> */}
            </div>
        )
    } else {
        return (
            <div>
                <div className="p-4">
                    <p>Loading...</p>
                </div>
            </div>
        )
    }
}