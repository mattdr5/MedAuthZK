// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./verifier.sol"; // Importa il contratto Verifier.sol generato da ZoKrates

contract MedicalRecordSBT is ERC721 {
    address private _owner;
    Verifier private verifier; // Istanza del contratto Verifier

    uint256 private _tokenCounter;

    struct MedicalRecord {
        uint256 tokenID;
        string id; // DID
        string name; // Nome
        string dateOfBirth; // Data di nascita
        string healthID; // ID sanitario
        mapping(string => bool) authorizedTreatment; // Mappatura delle diagnosi e permessi di trattamento
        string[] diagnosisKeys; // Lista delle diagnosi per eliminazione
        bool authenticated; // Utente autenticato con la malattia
    }


    mapping(address => MedicalRecord) private tokensIssued;
    mapping(string => address) private didToAddress; // Mappa il DID all'indirizzo dell'utente
    mapping(address => Verifier.Proof) private userProofs; // Mappa che associa un indirizzo alla sua prova ZKP

    event SBTIssued(address indexed requester, uint256 tokenID);
    event SBTRevoked(address indexed requester);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Solo il proprietario puo chiamare questa funzione");
        _;
    }

    constructor(address verifierAddress) ERC721("SBT", "SBT") {
        _owner = msg.sender;
        verifier = Verifier(verifierAddress); // Inizializza l'istanza del Verifier
        _tokenCounter = 0;
    }

    function requestSBT(
        string memory id, // DID
        string memory name, // Nome
        string memory dateOfBirth, // Data di nascita
        string memory healthID, // ID sanitario
        string memory diagnosis, // Diagnosi (hash della malattia)
        Verifier.Proof memory zkpProof, // Prova ZKP in formato struct
        uint256[1] memory inputs // Input per la verifica
    ) public {
        // Controlla che l'utente non abbia già utilizzato questa prova
        require(isProofEmpty(userProofs[msg.sender]), "Prova gia' utilizzata per questo utente");

        // Verifica della prova ZKP
        bool proofValid = verifier.verifyTx(zkpProof, inputs);
        require(proofValid, "Prova ZKP non valida");

        // Verifica che l'utente non abbia già un token emesso
        require(tokensIssued[msg.sender].tokenID == 0, "Token gia emesso per questo indirizzo");

        // Se la verifica è riuscita, emetti l'SBT e memorizza la prova
        _tokenCounter++;
        _safeMint(msg.sender, _tokenCounter);

        // Salva la prova nella mappatura
        userProofs[msg.sender] = zkpProof;

        // Inizializza la struttura MedicalRecord
        MedicalRecord storage record = tokensIssued[msg.sender];
        record.tokenID = _tokenCounter;
        record.id = id;
        record.name = name;
        record.dateOfBirth = dateOfBirth;
        record.healthID = healthID;
        record.authenticated = true;

        // Salva la diagnosi e autorizza il trattamento per essa
        record.authorizedTreatment[diagnosis] = true;
        record.diagnosisKeys.push(diagnosis); // Salva la diagnosi per eliminazione futura


        // Mappa il DID all'indirizzo dell'utente
        didToAddress[id] = msg.sender;

        emit SBTIssued(msg.sender, _tokenCounter);
    }

    function revokeSBT() public {
        require(tokensIssued[msg.sender].tokenID != 0, "Nessun SBT da revocare");

        MedicalRecord storage record = tokensIssued[msg.sender];
        uint256 tokenID = record.tokenID;

        // Brucia il token
        _burn(tokenID);

        // Rimuove l'associazione DID
        string memory userDID = record.id;
        delete didToAddress[userDID];

        // Cancella tutte le diagnosi autorizzate
        for (uint256 i = 0; i < record.diagnosisKeys.length; i++) {
            string memory diagnosis = record.diagnosisKeys[i];
            delete record.authorizedTreatment[diagnosis];
        }

        // Cancella l'array di diagnosi
        delete record.diagnosisKeys;

        // Infine, cancella il record medico completo e la prova ZKP associata
        delete tokensIssued[msg.sender];
        delete userProofs[msg.sender]; // Elimina la prova dell'utente

        emit SBTRevoked(msg.sender);
    }


    function getMedicalRecord(address owner) public view returns (
        uint256 tokenID,
        string memory id,
        string memory name,
        string memory dateOfBirth,
        string memory healthID,
        bool authenticated
    ) {
        MedicalRecord storage record = tokensIssued[owner];
        return (
            record.tokenID,
            record.id,
            record.name,
            record.dateOfBirth,
            record.healthID,
            record.authenticated
        );
    }

    function getUserProof(address user) public view returns (Verifier.Proof memory) {
        return userProofs[user]; // Restituisce la prova associata all'utente
    }

    // Verifica se l'utente con il DID specificato ha la malattia corrispondente all'hash fornito
    function canUserReceiveTreatment(string memory did, string memory hashedDiagnosis) public view returns (bool) {
        address userAddress = didToAddress[did];
        require(userAddress != address(0), "Nessun utente associato a questo DID");

        // Recupera il record medico associato all'utente e verifica il permesso per la diagnosi specifica
        return tokensIssued[userAddress].authorizedTreatment[hashedDiagnosis];
    }

    // Funzione per verificare se una prova è vuota
    function isProofEmpty(Verifier.Proof memory proof) internal pure returns (bool) {
        return (proof.a.X == 0 && proof.a.Y == 0 && proof.b.X[0] == 0 && proof.b.X[1] == 0 && proof.b.Y[0] == 0 && proof.b.Y[1] == 0 && proof.c.X == 0 && proof.c.Y == 0);
    }
}
