const fs = require('fs');
const path = require('path');

// Paths
const outDir = '../out';
const abisDir = './abis';

// Contract names and their corresponding JSON files
const contracts = {
  'PairFactory': '../out/PairFactory.sol/PairFactory.json',
  'Pair': '../out/Pair.sol/Pair.json',
  'RouterV2': '../out/RouterV2.sol/RouterV2.json',
  'GlobalRouter': '../out/GlobalRouter.sol/GlobalRouter.json',
  'PairFees': '../out/PairFees.sol/PairFees.json',
  'VotingEscrow': '../out/VotingEscrow.sol/VotingEscrow.json',
  'MinterUpgradeable': '../out/MinterUpgradeable.sol/MinterUpgradeable.json',
  'GaugeV2': '../out/GaugeV2.sol/GaugeV2.json',
  'BribeFactoryV3': '../out/BribeFactoryV3.sol/BribeFactoryV3.json',
  'VoterV3': '../out/VoterV3.sol/VoterV3.json',
  'ERC20': '../out/IERC20.sol/IERC20.json'
};

// Create abis directory if it doesn't exist
if (!fs.existsSync(abisDir)) {
  fs.mkdirSync(abisDir, { recursive: true });
}

// Extract ABIs
for (const [contractName, jsonPath] of Object.entries(contracts)) {
  try {
    const fullPath = path.resolve(__dirname, jsonPath);
    
    if (fs.existsSync(fullPath)) {
      const contractJson = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
      const abi = contractJson.abi;
      
      // Write ABI to file
      const abiPath = path.join(abisDir, `${contractName}.json`);
      fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2));
      
      console.log(`✅ Extracted ABI for ${contractName}`);
    } else {
      console.log(`⚠️  Contract JSON not found: ${fullPath}`);
      
      // Create a basic ABI structure for missing contracts
      const basicAbi = [];
      const abiPath = path.join(abisDir, `${contractName}.json`);
      fs.writeFileSync(abiPath, JSON.stringify(basicAbi, null, 2));
      console.log(`📝 Created empty ABI for ${contractName}`);
    }
  } catch (error) {
    console.error(`❌ Error processing ${contractName}:`, error.message);
  }
}

console.log('\n🎉 ABI extraction completed!');
console.log('\n📋 Next steps:');
console.log('1. Update subgraph.yaml with correct contract addresses');
console.log('2. Update subgraph.yaml with correct start blocks');
console.log('3. Update subgraph.yaml with correct network');
console.log('4. Run: npm install');
console.log('5. Run: npm run codegen');
console.log('6. Run: npm run build');