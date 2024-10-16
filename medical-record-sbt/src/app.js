const loginButton = document.getElementById("loginButton");
const sbtInfo = document.getElementById("sbtInfo");
const detailsDiv = document.getElementById("details");

loginButton.addEventListener("click", async () => {
    if (typeof window.ethereum !== "undefined") {
        try {
            // Richiesta di accesso a MetaMask
            await window.ethereum.request({ method: "eth_requestAccounts" });
            const provider = new ethers.providers.Web3Provider(window.ethereum); // Corretto qui
            const signer = provider.getSigner();
            const address = await signer.getAddress();
            console.log("Account connesso:", address);

            // Reindirizza a una nuova pagina che mostra l'indirizzo e il pulsante per l'SBT
            localStorage.setItem("userAddress", address);  // Memorizza l'indirizzo nell'archiviazione locale
            window.location.href = "sbtPage.html"; // Reindirizza alla nuova pagina
        } catch (error) {
            console.error("Errore di accesso:", error);
            alert("Errore durante la connessione a MetaMask: " + error.message);
        }
    } else {
        alert("MetaMask non è installato!");
    }
});


