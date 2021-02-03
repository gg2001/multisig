const { expect } = require("chai");

describe("MultiSig contract", function () {
  let MultiSig;
  let multiSig1;
  let multiSig2;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    MultiSig = await ethers.getContractFactory("MultiSig");
    [owner, addr1, ...addrs] = await ethers.getSigners();

    multiSig1 = await MultiSig.deploy([owner.address], 1);
    multiSig2 = await MultiSig.deploy([owner.address, addr1.address], 1);

    expect(await owner.sendTransaction({ to: multiSig1.address, value: ethers.utils.parseEther("1.0") }))
      .to.changeEtherBalance(multiSig1, ethers.utils.parseEther("1.0"));
    expect(await owner.sendTransaction({ to: multiSig2.address, value: ethers.utils.parseEther("1.0") }))
      .to.changeEtherBalance(multiSig2, ethers.utils.parseEther("1.0"));
  });

  describe("Deployment", function () {
    it("Sets correct number of owners", async function () {
      expect((await multiSig1.getOwners()).length).to.equal(1);
      expect((await multiSig2.getOwners()).length).to.equal(2);
    });

    it("Sets correct owners", async function () {
      expect(await multiSig1.owners(0)).to.equal(owner.address);
      expect(await multiSig1.getOwners()).to.deep.equal([owner.address]);

      expect(await multiSig2.owners(0)).to.equal(owner.address);
      expect(await multiSig2.owners(1)).to.equal(addr1.address);
      expect(await multiSig2.getOwners()).to.deep.equal([owner.address, addr1.address]);
    });

    it("Sets correct confirmations", async function () {
      expect(await multiSig1.confirmationsRequired()).to.equal(1);
      expect(await multiSig2.confirmationsRequired()).to.equal(1);
    });
  });

  describe("MultiSig", function () {
    it("Emits Deposit event", async function () {
      expect(await ethers.provider.getBalance(multiSig1.address)).to.equal(ethers.utils.parseEther("1.0"));

      await expect(owner.sendTransaction({ to: multiSig1.address, value: ethers.utils.parseEther("1.0") }))
        .to.emit(multiSig1, 'Deposit').withArgs(owner.address, ethers.utils.parseEther("1.0"), ethers.utils.parseEther("2.0"));

      expect(await ethers.provider.getBalance(multiSig1.address)).to.equal(ethers.utils.parseEther("2.0"));
    });

    it("Submit and confirm works", async function () {
      await expect(multiSig1.confirmTransaction(0)).to.be.revertedWith('tx does not exist');
      await expect(multiSig1.submitTransaction(addr1.address, ethers.utils.parseEther("0.1"), []))
        .to.emit(multiSig1, 'SubmitTransaction').withArgs(owner.address, 0, addr1.address, ethers.utils.parseEther("0.1"), []);
      await expect(multiSig1.confirmTransaction(0))
        .to.emit(multiSig1, 'ConfirmTransaction').withArgs(owner.address, 0);
      expect(await multiSig1.isConfirmed(0, owner.address))
        .to.equal(true);
      await expect(multiSig1.confirmTransaction(0))
        .to.be.revertedWith('tx already confirmed');
      expect(await multiSig1.getTransactionCount())
        .to.equal(1);

      expect((await multiSig1.getTransaction(0)).to)
        .to.equal(addr1.address);
      expect((await multiSig1.getTransaction(0)).value)
        .to.equal(ethers.utils.parseEther("0.1"));
      expect((await multiSig1.getTransaction(0)).data)
        .to.equal("0x");
      expect((await multiSig1.getTransaction(0)).executed)
        .to.equal(false);
      expect((await multiSig1.getTransaction(0)).numConfirmations)
        .to.equal(1);

      await expect(multiSig2.submitTransaction(addr1.address, ethers.utils.parseEther("0.1"), []))
        .to.emit(multiSig2, 'SubmitTransaction').withArgs(owner.address, 0, addr1.address, ethers.utils.parseEther("0.1"), []);
      await expect(multiSig2.connect(addr1).confirmTransaction(0))
        .to.emit(multiSig2, 'ConfirmTransaction').withArgs(addr1.address, 0);
      expect(await multiSig2.isConfirmed(0, addr1.address))
        .to.equal(true);
      await expect(multiSig2.confirmTransaction(0))
        .to.emit(multiSig2, 'ConfirmTransaction').withArgs(owner.address, 0);
      expect(await multiSig2.isConfirmed(0, owner.address))
        .to.equal(true);

      expect((await multiSig2.getTransaction(0)).to)
        .to.equal(addr1.address);
      expect((await multiSig2.getTransaction(0)).value)
        .to.equal(ethers.utils.parseEther("0.1"));
      expect((await multiSig2.getTransaction(0)).data)
        .to.equal("0x");
      expect((await multiSig2.getTransaction(0)).executed)
        .to.equal(false);
      expect((await multiSig2.getTransaction(0)).numConfirmations)
        .to.equal(2);
    });

    it("Execution works", async function () {
    });
  });
});