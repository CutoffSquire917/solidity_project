const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

const ABI = [
    "function createProduct(string name, string description, uint256 price, string imageUrl)",
    "function getProducts() view returns (tuple(string name, string description, uint256 price, address creator, uint256 createdAt, string imageUrl)[])"
];

const statusEl = document.getElementById("status");
const bodyEl = document.getElementById("products-body");
const formEl = document.getElementById("product-form");
const submitBtn = document.getElementById("submit-btn");
const connectBtn = document.getElementById("connect-btn");
const refreshBtn = document.getElementById("refresh-btn");

const setStatus = (message, type) => {
    statusEl.textContent = message;
    statusEl.className = "status" + (type ? " " + type : "");
};

const clearStatus = () => {
    statusEl.className = "status hidden";
    statusEl.textContent = "";
};

const shortAddress = (address) => address.slice(0, 6) + "..." + address.slice(-4);

const errorMessage = (error) => error?.reason || error?.shortMessage || error?.message || "Unknown error";

const getProvider = () => {
    if (!window.ethereum) {
        throw new Error("Please install web3 provider. (Metamask https://metamask.io/)");
    }
    return new ethers.BrowserProvider(window.ethereum);
};

const ensureContractExists = async (provider) => {
    const code = await provider.getCode(CONTRACT_ADDRESS);
    if (code === "0x") {
        throw new Error("No contract at " + CONTRACT_ADDRESS + " on the selected network. Check the network and the address.");
    }
};

const makeCell = (text, className) => {
    const td = document.createElement("td");
    td.textContent = text;
    if (className) {
        td.className = className;
    }
    return td;
};

const makeImageCell = (url) => {
    const td = document.createElement("td");
    if (!/^https?:\/\//i.test(url)) {
        td.textContent = "-";
        return td;
    }
    const img = document.createElement("img");
    img.className = "thumb";
    img.alt = "Product image";
    img.referrerPolicy = "no-referrer";
    img.src = url;
    img.addEventListener("error", () => {
        td.textContent = "Image unavailable";
    });
    td.appendChild(img);
    return td;
};

const renderProducts = (products) => {
    bodyEl.replaceChildren();
    if (products.length === 0) {
        const tr = document.createElement("tr");
        const td = makeCell("No products yet", "empty");
        td.colSpan = 6;
        tr.appendChild(td);
        bodyEl.appendChild(tr);
        return;
    }
    [...products].reverse().forEach((p) => {
        const tr = document.createElement("tr");
        tr.appendChild(makeCell(p.name));
        tr.appendChild(makeCell(p.description || "-", "desc"));
        tr.appendChild(makeCell(ethers.formatEther(p.price) + " ETH"));
        const creator = makeCell(shortAddress(p.creator), "addr");
        creator.title = p.creator;
        tr.appendChild(creator);
        tr.appendChild(makeCell(new Date(Number(p.createdAt) * 1000).toLocaleString()));
        tr.appendChild(makeImageCell(p.imageUrl));
        bodyEl.appendChild(tr);
    });
};

const loadProducts = async () => {
    try {
        const provider = getProvider();
        await ensureContractExists(provider);
        const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);
        const products = await contract.getProducts();
        renderProducts(products);
        clearStatus();
    } catch (error) {
        setStatus(errorMessage(error), "error");
    }
};

const connectWallet = async () => {
    try {
        const provider = getProvider();
        const signer = await provider.getSigner();
        const address = await signer.getAddress();
        connectBtn.textContent = shortAddress(address);
        return signer;
    } catch (error) {
        setStatus(errorMessage(error), "error");
        return null;
    }
};

const createProduct = async (event) => {
    event.preventDefault();

    const name = document.getElementById("name").value.trim();
    const description = document.getElementById("description").value.trim();
    const image = document.getElementById("image").value.trim();
    const priceInput = document.getElementById("price").value.trim().replace(",", ".");

    let price;
    try {
        price = ethers.parseEther(priceInput);
    } catch {
        setStatus("Price must be a valid number", "error");
        return;
    }

    submitBtn.disabled = true;
    try {
        const signer = await connectWallet();
        if (!signer) {
            return;
        }
        await ensureContractExists(signer.provider);
        const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, signer);
        setStatus("Waiting for confirmation in wallet...");
        const tx = await contract.createProduct(name, description, price, image);
        setStatus("Transaction sent, waiting for it to be mined...");
        await tx.wait();
        formEl.reset();
        await loadProducts();
        setStatus("Product created", "ok");
    } catch (error) {
        setStatus(errorMessage(error), "error");
    } finally {
        submitBtn.disabled = false;
    }
};

formEl.addEventListener("submit", createProduct);
connectBtn.addEventListener("click", connectWallet);
refreshBtn.addEventListener("click", loadProducts);

if (window.ethereum) {
    window.ethereum.on("chainChanged", () => window.location.reload());
    window.ethereum.on("accountsChanged", () => window.location.reload());
}

document.addEventListener("DOMContentLoaded", loadProducts);