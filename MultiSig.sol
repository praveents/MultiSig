pragma solidity ^0.4.20;


contract NewMultiSig {

    address private contractOwner;

    struct BeneficiaryData {
        uint256 _proposedValue;
        mapping (address=>uint8) _approved;
        uint8 _approveCnt;
        uint8 _rejectCnt;
        uint8 _index;
        uint8 _used;
    }

    mapping (address => uint256) private contributions;

    mapping (address => BeneficiaryData) private beneficiaryData;

    address[] private _listbeneficiaries;

    address[] private _listOfContributors;

    bool private _bContributionPeriod = true;

    uint private _totalContractValue = 0;

    uint private _totalProposedValue = 0;

    address[]  private signers = [address(0xfA3C6a1d480A14c546F12cdBB6d1BaCBf02A1610),
    address(0x2f47343208d8Db38A64f49d7384Ce70367FC98c0),
    address(0x7c0e7b2418141F492653C6bF9ceD144c338Ba740)];

    //address[]  public signers = [address( 0xAD6127F0Df826158EFf832460abcEf3f521f970a),
    //address(0x0500c210DC86aB1c87350d047a411A3ec6d22286),
    //address(0x4d12e3F6110C55e132E9C49Ed7f1D46740E4C1dF)];

    
        
    event ProposalSubmitted(address indexed _beneficiary, uint _valueInWei);
    
    event ProposalApproved(address indexed _approver, address indexed _beneficiary, uint _valueInWei);
    
    event ProposalRejected(address indexed _rejecter, address indexed _beneficiary, uint _valueInWei);
    
    event WithdrawPerformed(address indexed _beneficiary, uint _valueInWei);

    /*
    * This event should be dispatched whenever the contract receives
    * any contribution.
    */
    event ReceivedContribution(address indexed _contributor, uint _valueInWei);


    function NewMultiSig() public {
        contractOwner = msg.sender;
    }

    address[] private openproposal;

    function( ) public payable {
        require(_bContributionPeriod == true);
        require(msg.value > 0);
        if (contributions[msg.sender] == 0) {
            contributions[msg.sender] = msg.value;
            _listOfContributors.push(msg.sender);
            } else {
                contributions[msg.sender] += msg.value;
            }
            _totalContractValue += msg.value;

           ReceivedContribution(msg.sender, msg.value);
        }

    /*
    * This function should return the onwer of this contract or whoever you
    * want to receive the Gyaan Tokens reward if it's coded correctly.
    */
    function owner() external view returns(address) {
        return contractOwner;
    }

    /*
    * When this contract is initially created, it's in the state
    * "Accepting contributions". No proposals can be sent, no withdraw
    * and no vote can be made while in this state. After this function
    * is called, the contract state changes to "Active" in which it will
    * not accept contributions anymore and will accept all other functions
    * (submit proposal, vote, withdraw)
    */
    function endContributionPeriod() external {
        require(msg.sender == signers[0] || msg.sender == signers[1] || msg.sender == signers[2]);
        require(_totalContractValue > 0);
        _bContributionPeriod = false;

    }

    /*
    * Sends a withdraw proposal to the contract. The beneficiary would
    * be "_beneficiary" and if approved, this address will be able to
    * withdraw "value" Ethers.
    *
    * This contract should be able to handle many proposals at once.
    */
    function submitProposal(uint _valueInWei) external {
        require(_bContributionPeriod == false);
        require(_valueInWei > 0);
        require(_valueInWei <= uint(_totalContractValue/10));
        require(beneficiaryData[msg.sender]._proposedValue == 0);
        require(msg.sender != signers[0] && msg.sender != signers[1] && msg.sender != signers[2]);
        require(_valueInWei <= uint(_totalContractValue-_totalProposedValue));
        beneficiaryData[msg.sender]._proposedValue = _valueInWei;
        if (beneficiaryData[msg.sender]._used != 0) {
            _listbeneficiaries[beneficiaryData[msg.sender]._index] = msg.sender;
            } else {
                _listbeneficiaries.push(msg.sender);
                beneficiaryData[msg.sender]._index = uint8(_listbeneficiaries.length - 1);
                beneficiaryData[msg.sender]._used = 1;
            }
            _totalProposedValue += _valueInWei;
	    updateOpenBeneficiariesProposals();
            ProposalSubmitted(msg.sender, _valueInWei);
        }

    /*
    * Returns a list of beneficiaries for the open proposals. Open
    * proposal is the one in which the majority of voters have not
    * voted yet.
    */
    function listOpenBeneficiariesProposals() external view returns (address[]) {
        return openproposal;
    }

    /*
    * Returns the value requested by the given beneficiary in his proposal.
    */
    function getBeneficiaryProposal(address _beneficiary) external view returns (uint) {

        require(_bContributionPeriod == false);
        require(beneficiaryData[_beneficiary]._proposedValue > 0);
        return beneficiaryData[_beneficiary]._proposedValue;
    }

    /*
    * List the addresses of the contributors, which are people that sent
    * Ether to this contract.
    */
    function listContributors() external view returns (address[]) {
        return _listOfContributors;
    }

    /*
    * Returns the amount sent by the given contributor in Wei.
    */
    function getContributorAmount(address _contributor) external view returns (uint) {
        require(contributions[_contributor] > 0);
        return contributions[_contributor];
    }

    /*
    * Approve the proposal for the given beneficiary
    */
    function approve(address _beneficiary) external {
        require(_bContributionPeriod == false);
        require(msg.sender == signers[0] || msg.sender == signers[1] || msg.sender == signers[2]);
        require(beneficiaryData[_beneficiary]._proposedValue > 0);
        require(beneficiaryData[_beneficiary]._approved[msg.sender] == 0);
        beneficiaryData[_beneficiary]._approved[msg.sender] = 1;
        beneficiaryData[_beneficiary]._approveCnt += 1;
        updateOpenBeneficiariesProposals();
        ProposalApproved(msg.sender, _beneficiary, beneficiaryData[_beneficiary]._proposedValue);
    }

        /*
    * Reject the proposal of the given beneficiary
    */
    function reject(address _beneficiary) external {
        require(_bContributionPeriod == false);
        require(msg.sender == signers[0] || msg.sender == signers[1] || msg.sender == signers[2]);
        require(beneficiaryData[_beneficiary]._proposedValue > 0);
        require(beneficiaryData[_beneficiary]._approved[msg.sender] == 0);
        beneficiaryData[_beneficiary]._approved[msg.sender] = 2;
        beneficiaryData[_beneficiary]._rejectCnt += 1;
        if ((beneficiaryData[_beneficiary]._rejectCnt + beneficiaryData[_beneficiary]._approveCnt) >= 3) {
            if (beneficiaryData[_beneficiary]._rejectCnt >= 2) {
                _totalProposedValue -= beneficiaryData[_beneficiary]._proposedValue;
                delete _listbeneficiaries[beneficiaryData[_beneficiary]._index];
                beneficiaryData[_beneficiary]._approved[signers[0]] = 0;
                beneficiaryData[_beneficiary]._approved[signers[1]] = 0;
                beneficiaryData[_beneficiary]._approved[signers[2]] = 0;
                beneficiaryData[_beneficiary]._approveCnt = 0;
                beneficiaryData[_beneficiary]._rejectCnt = 0;
                beneficiaryData[_beneficiary]._proposedValue = 0;
                updateOpenBeneficiariesProposals();
            }
        }
        ProposalRejected(msg.sender, _beneficiary, beneficiaryData[_beneficiary]._proposedValue);
    }

    /*
    * Withdraw the specified value in Wei from the wallet.
    * The beneficiary can withdraw any value less than or equal the value
    * he/she proposed. If he/she wants to withdraw more, a new proposal
    * should be sent.
    *
    */
    function withdraw(uint _valueInWei) external {
        require(_valueInWei > 0);
        require(_bContributionPeriod == false);
        require(beneficiaryData[msg.sender]._proposedValue >= _valueInWei);
        require((beneficiaryData[msg.sender]._rejectCnt + beneficiaryData[msg.sender]._approveCnt) >= 3);
        require(beneficiaryData[msg.sender]._approveCnt >= 2);
        require(beneficiaryData[msg.sender]._approveCnt > beneficiaryData[msg.sender]._rejectCnt);
        beneficiaryData[msg.sender]._proposedValue -= _valueInWei;
        if (beneficiaryData[msg.sender]._proposedValue == 0) {
            delete _listbeneficiaries[beneficiaryData[msg.sender]._index];
            beneficiaryData[msg.sender]._approved[signers[0]] = 0;
            beneficiaryData[msg.sender]._approved[signers[1]] = 0;
            beneficiaryData[msg.sender]._approved[signers[2]] = 0;
            beneficiaryData[msg.sender]._approveCnt = 0;
            beneficiaryData[msg.sender]._rejectCnt = 0;
            beneficiaryData[msg.sender]._proposedValue = 0;
	    updateOpenBeneficiariesProposals();
        }
        msg.sender.transfer(_valueInWei);
        WithdrawPerformed(msg.sender, _valueInWei);
    }

    /*
    * Returns whether a given signer has voted in the given proposal and if so,
    * what was his/her vote.
    *
    * @returns 0: if signer has not voted yet in this proposal, 1: if signer
    * has voted YES in this proposal, 2: if signer has voted NO in this proposal
    */
    function getSignerVote(address _signer, address _beneficiary) view external returns(uint) {
        require(_bContributionPeriod == false);
        require(beneficiaryData[_beneficiary]._proposedValue >= 0);
        require (_signer == signers[0] || _signer == signers[1] || _signer == signers[2]);
        uint8 _vote = beneficiaryData[_beneficiary]._approved[_signer];
        return _vote;
    }

    function updateOpenBeneficiariesProposals() internal {
        delete openproposal;
        for (uint i=0; i < _listbeneficiaries.length; i++) {
            if (_listbeneficiaries[i] != address(0) &&
            (beneficiaryData[_listbeneficiaries[i]]._rejectCnt + beneficiaryData[_listbeneficiaries[i]]._approveCnt) < 3){
                openproposal.push(_listbeneficiaries[i]);
            }
        }
    }

}   

