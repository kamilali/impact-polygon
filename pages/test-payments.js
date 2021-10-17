import { ethers } from "ethers";
import { useEffect, useState } from "react";
import axios from "axios";
import Web3Modal from "web3modal";
const Web3 = require("web3");
const { RelayProvider } = require('@opengsn/gsn');

import { impactPaymentAddress, impactPaymasterAddress } from "../config";

import ImpactPayment from '../artifacts/contracts/ImpactPayment.sol/ImpactPayment.json';
import ImpactPaymaster from '../artifacts/contracts/ImpactPaymaster.sol/ImpactPaymaster.json';

const daiTokenAddress = "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa";

const WEB3_PROVIDER = 'https://rinkeby.infura.io/v3/959dde76f6ab4023870800531d390fc6';

const config = { 
    paymasterAddress: impactPaymasterAddress,
    loggerConfiguration: {
        logLevel: 'debug',
        // loggerUrl: 'logger.opengsn.org',
    }
}

async function payDaiTest() {
    console.log("Testing DAI payments");
    const expiry = Date.now() + 120;
    const nonce = 1;
    const spender = impactPaymentAddress;

    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    const paymentContractSigned = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    const paymasterContractSigned = new ethers.Contract(impactPaymasterAddress, ImpactPaymaster.abi, signer);
    const fromAddress = await signer.getAddress();
    console.log(fromAddress);

    // paymasterContractSigned._depositProceedsToHubPublic("100000000000000000");

    // await paymentContract.methods.testContractFunction(100).send({ from: fromAddress });

    // call permit to allow access for impact payment contract
    const gsnProvider = await RelayProvider.newProvider({ provider: window.ethereum, config }).init()
    const web3 = new Web3(gsnProvider);
    const paymentContract = new web3.eth.Contract(ImpactPayment.abi, impactPaymentAddress);

    var signedData = await signTransferPermit(fromAddress, expiry, nonce, spender);
    console.log(signedData);
    await paymentContract.methods.permitContractWithdrawals(
        daiTokenAddress,signedData.holder, signedData.spender, signedData.nonce,
        signedData.expiry, signedData.allowed, signedData.v, signedData.r, signedData.s).send({ from: fromAddress, gas: 1500000 });
    // await paymentContract.methods.testContractFunction(10).send({ from: fromAddress, gas: 1500000 });

    // const paymentContract = new ethers.Contract(impactPaymentAddress, ImpactPayment.abi, signer);
    // let daiAmount = ethers.utils.formatUnits(0.01, 'ether');
    // let transaction = await paymentContract.depositFunds(daiTokenAddress, daiAmount);
    // tx = await transaction.wait();
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
        chainId: 4,
        verifyingContract: "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735",
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
    useEffect(() => {
        connectUser();
    }, []);

    async function connectUser() {
        setLoadingState(true);
        const web3Modal = new Web3Modal();
        const connection = await web3Modal.connect();
        const provider = new ethers.providers.Web3Provider(connection);
        const signer = provider.getSigner();
        const signerAddress = await signer.getAddress();
        setLoadingState(false);
    }

    if (!loadingState) {
        return (
            <div>
                <div className="p-4">
                    <h2 className="text-2xl py-2">Impact Payments Testing</h2>
                    <button className="w-50 bg-pink-500 text-white font-bold py-2 px-12 rounded" onClick={() => payDaiTest()}>Pay in DAI</button>
                </div>
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