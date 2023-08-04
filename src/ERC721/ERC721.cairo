#[starknet::contract]
mod ERC721 {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use traits::PartialEq;

    use NepMarket::ERC721::interface::IERC165;
    use NepMarket::ERC721::interface::IERC721;
    use NepMarket::ERC721::interface::IERC721Metadata;
    use NepMarket::error;

    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _owners: LegacyMap<u256, ContractAddress>,
        _balances: LegacyMap<ContractAddress, u256>,
        _token_approvals: LegacyMap<u256, ContractAddress>,
        // owner operator access
        _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        _token_uri: LegacyMap<u256, felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _name: felt252, _symbol: felt252) {
        self._name.write(_name);
        self._symbol.write(_symbol);
    }

    // ========= event =========

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
        Transfer: Transfer
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        operator: ContractAddress,
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256
    }

    // ========= external =========

    #[external(v0)]
    impl ERC165Impl of IERC165<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            true
        }
    }

    #[external(v0)]
    impl ERC721Impl of IERC721<ContractState> {
        // ======== view ========
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(account.is_non_zero(), error::ZERO_ADDRESS);
            self._balances.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self._owners.read(token_id);
            assert(owner.is_non_zero(), error::ZERO_ADDRESS);
            owner
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self._operator_approvals.read((owner, operator))
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), error::TOKEN_NOT_EXIST);
            self._token_approvals.read(token_id)
        }


        // ======== storage ========
        fn approve(ref self: ContractState, token_id: u256, operator: ContractAddress) {
            let owner = self._owners.read(token_id);
            let msg_sender = get_caller_address();
            assert(
                owner == msg_sender || self.is_approved_for_all(owner, msg_sender),
                error::NO_ACCESS_OF_TOKEN
            );
            self._operator_approvals.write((owner, msg_sender), true);

            self
                .emit(
                    Event::Approval(
                        Approval { owner: owner, operator: msg_sender, token_id: token_id }
                    )
                )
        }

        fn set_approve_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
            let msg_sender = get_caller_address();
            assert(msg_sender != operator, error::OPERATOR_ERROR);
            self._operator_approvals.write((msg_sender, operator), approved);

            self
                .emit(
                    Event::ApprovalForAll(
                        ApprovalForAll { owner: msg_sender, operator: operator, approved: approved }
                    )
                )
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            let msg_sender = get_caller_address();
            let owner = self._owners.read(token_id);
            let operator = self._token_approvals.read(token_id);

            assert(self._is_approved_or_owner(msg_sender, token_id), error::NO_ACCESS_OF_TOKEN);

            self._transfer(from, to, token_id);
        }

        // everyone can mint it.
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256){
            assert(!to.is_zero(), error::ZERO_ADDRESS);
            assert(!self._exists(token_id), error::TOKEN_NOT_EXIST);

            self._balances.write(to, self._balances.read(to) + 1);
            self._owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }
    }

    #[external(v0)]
    impl ERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }
        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }
        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            assert(self._exists(token_id), error::TOKEN_NOT_EXIST);
            self._token_uri.read(token_id)
        }
    }

    // TODO: where is the InternalTrait?
    // Hi, I'm Shalom, and I'm a smart contract developer. 
    // When I saw an NFT contract from openzepplin, 
    // I noticed an implementation of InternalTrait marked by #[generate_trait] attribute for the internal functions.
    // But I didn't meet it before, could you explain it for me?

    // another question is about strings. 
    // Currently cairo only supports short string, will cairo support long string?
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _exists(self: @ContractState, token_id: u256) -> bool {
            !self._owners.read(token_id).is_zero()
        }

        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owners.read(token_id);
            let is_approved_for_all = ERC721Impl::is_approved_for_all(self, owner, spender);

            spender == owner
                || is_approved_for_all
                || spender == ERC721Impl::get_approved(self, token_id)
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            let owner = self._owners.read(token_id);
            assert(owner == from, error::NO_ACCESS_OF_TOKEN);
            assert(to.is_non_zero(), error::ZERO_ADDRESS);

            // address(0)
            self._token_approvals.write(token_id, Zeroable::zero());

            self._balances.write(from, self._balances.read(from) - 1);
            self._balances.write(to, self._balances.read(to) + 1);

            self._owners.write(token_id, to);

            // emit event
            self.emit(Transfer { from, to, token_id });
        }
    }
}
