// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SampleNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    address public metadataSigner;

    uint256 constant public MINT_PRICE = 0.2 ether;
    uint256 constant public TOTAL_SUPPLY = 100; 

    Counters.Counter private _tokenIdCounter;

    // Optional mapping for token URIs - sort of like in ERC721URIStorage
    mapping(uint256 => string) private _tokenURIs;

    string private _baseTokenURI;

    constructor() ERC721("Sample NFT", "SNFT") {
        setBaseTokenURI("https://some-metadata-url.com/");
        _setMetadataSigner(0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199);
        _tokenIdCounter.increment();  // Always start the counter at 1 to avoid empty memory gas penalty 
    }

    /**
     * @notice Internal setter for trusted metadata signer
     * @param signer Public ethereum address of a trusted signer
     */
    function _setMetadataSigner(address signer) public onlyOwner {
        metadataSigner = signer;
    }

    /**
     * @notice Internal function to set the base token URI.
     * @param uri string base URI to assign
     */
    function setBaseTokenURI(string memory uri) public onlyOwner {
        _baseTokenURI = uri;
    }

    /**
     * @notice Sets stream ID for a given token
     * @dev Reimplementation of OpenZeppelins ERC721URIStorage setTokenURI method
     * @param tokenId token ID 
     * @param _tokenURI The URI to be set for token ID
     */
    function setTokenURI(uint256 tokenId, string memory _tokenURI) private {
        require(_exists(tokenId),  "URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @notice Verifies that the provided signature was produced by the correct signer from the given message
     * @param metadata string containing the ceramic stream ID
     * @param signature backend-produced signature to verify the correctness of metadata
     */
    function _verify(
        string memory metadata,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(metadata)).toEthSignedMessageHash();
        (address recoveredSigner, ECDSA.RecoverError recoverError) = ethSignedMessageHash.tryRecover(signature);
        require(recoverError == ECDSA.RecoverError.NoError);
        require(recoveredSigner == metadataSigner, "Metadata signed by unstrusted signer");
        return true;
    }

    /**
     * @notice Function implementing NFT minting for both generations
     * @param metadataURI URI pointing to metadata - IPFS CID or Ceramic Stream ID
     * @param signature metadataURI signer by trusted metadata signer
     */
    function payToMint(
        string memory metadataURI,
        bytes memory signature
    ) public payable {
        _verify(metadataURI, signature);
        require(msg.value == MINT_PRICE, "Not enough ETH trasferred through!");
        uint256 newItemId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _mint(msg.sender, newItemId);
        setTokenURI(newItemId, metadataURI);
    }

    /**
     * @notice Implements returning complete metadata URI
     * @param tokenId Token ID
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");
        return string(abi.encodePacked(_baseTokenURI, _tokenURIs[tokenId]));
    }

    /**
     * @notice Implements returning total minted tokens
     * @dev This number does not take into account tokens that have been burned,
     * @dev there could be less tokens in circulation than provided by this function
     */
    function totalCount() public view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }
}