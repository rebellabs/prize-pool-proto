const { expect } = require("chai")
const { ethers, waffle } = require("hardhat")
const crypto = require("crypto")

describe("Testing contract: SampleNFT", function () {

  let sampleNFTFactory
  let sampleNFT
  let addr1
  let addr2
  let addrs

  const GEN0_MINT_PRICE = ethers.BigNumber.from("200000000000000000") //wei

  // Hardcoded to hardhat wallet #19
  // Account #19: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 
  const metadataSignerKey = '0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e'
  const metadataSigner = new ethers.Wallet(metadataSignerKey)

  // A provider connected to hardhad local node employed in these tests - to check for ETH balance for instance
  const localProvider = waffle.provider

  before(async function () {
    // Get the ContractFactory and Signers here.
    sampleNFTFactory = await ethers.getContractFactory("SampleNFT");
    [addr1, addr2, ...addrs] = await ethers.getSigners();
    sampleNFT = await sampleNFTFactory.deploy();
    await sampleNFT.deployed();
  })

  // `beforeEach` will run before each test, it receives a callback, which can be async
  beforeEach(async function () {
    // 
  })

  async function getMetadataURIAndSignature() {
    const METADATA_STRING_LENGTH = 30

    // Generate random metadata string and sign it
    const someMetadataURI = crypto.randomBytes(METADATA_STRING_LENGTH).toString('hex')
    const metadataHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(someMetadataURI))
    let metadataHashBinary = ethers.utils.arrayify(metadataHash)
    const signature = await metadataSigner.signMessage(metadataHashBinary)

    // Return as an array
    return [someMetadataURI, signature]
  }

  describe("Mint", function () {
    it('Mint a single NFT', async function () { 
      // Generate random signer

      // Generate random streamID and sign it
      const [someMetadataURI, signature] = await getMetadataURIAndSignature()     
      
      await sampleNFT.connect(addr1).payToMint(someMetadataURI, signature, { value: GEN0_MINT_PRICE })

      const balance = await sampleNFT.balanceOf(addr1.address)
      expect(balance).to.equal(1)
    })  
  })
})
