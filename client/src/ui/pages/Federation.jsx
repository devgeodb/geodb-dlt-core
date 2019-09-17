import React from "react";
import { Button, Row, Col } from "react-bootstrap";
import fs from "fs-extra";
import path from "path";

import { NotificationManager } from "react-notifications";
import Nav from "react-bootstrap/Nav";

import Loading from "../components/Loading.jsx";
import SetupOrgModal from "../components/SetupOrgModal.jsx";
import FederationOrgBrowser from "../components/FederationOrgBrowser.jsx";
import FederationDashboard from "../components/FederationDashboard.jsx";

const errors = {
  noCertificatePathFound: "No certificate path found",
  certificatePathDoesNotExist: "Certificate path does not exist",
  noOrgsFound: "Orgs not found"
};

class Federation extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      loadingUserConfig: true,
      showSetupOrgModal: false,
      selectedOrg: {},
      organizations: []
    };
  }

  handleAddOrg = () => {
    this.setState({ showSetupOrgModal: true });
  };

  handleRemoveOrg = organization => {
    const { db, mode } = this.props;

    console.log(organization);
    if (organization === "operations.geodb.com" && mode === "local") {
      NotificationManager.error("Cannot remove the base local organization.");
      return;
    }

    db[mode]
      .remove({ _id: organization })
      .then(result => {
        this.checkCertificates();
      })
      .catch(error => console.log);
  };

  handleShowOrg = selectedOrg => {
    this.setState({ selectedOrg });
  };

  checkCertificates = () => {
    const { db, mode } = this.props;

    // let certInfo = {
    //   mspPath: "",
    //   domain: "",
    //   peerCrt: "",
    //   adminCrt: "",
    //   intermediateCrt: ""
    // };

    let organizations = [];
    if (mode === "local") organizations.push({ _id: "operations.geodb.com", domain: "operations.geodb.com" });

    db[mode]
      .find()
      .then(results => {
        if (results.length === 0) {
          throw errors.noOrgsFound;
          // => Trigger CA setup
        }

        for (let i = 0; i < results.length; i++) {
          if (results[i].mspPath && results[i].domain) {
            organizations.push(results[i]);
          }
        }

        this.setState({ organizations, selectedOrg: organizations[0] });
      })
      .catch(err => {
        switch (err) {
          case errors.noOrgsFound:
            this.setState({
              organizations,
              selectedOrg: organizations && organizations.length > 0 ? organizations[0] : {},
              showSetupOrgModal: mode === "gcp"
            });
            break;
          default:
            NotificationManager.error(`${err}`, "Failed to run command");
            console.error(err);
        }
      })
      .finally(() => {
        this.setState({ loadingUserConfig: false });
      });
  };

  closeSetupOrgModal = success => {
    this.setState({ showSetupOrgModal: false });

    if (success) this.checkCertificates();
  };

  componentDidMount() {
    this.checkCertificates();
  }

  renderRemoveButton = () => {
    return <Button variant="outline-primary">Delete</Button>;
  };

  render() {
    const { db, mode } = this.props;
    const { loadingUserConfig, showSetupOrgModal, selectedOrg, organizations } = this.state;
    // const {peerCrt, adminCrt, intermediateCACrt} = certInfo;

    // const x509props = { peerCrt, adminCrt, intermediateCACrt };

    if (loadingUserConfig) return <Loading />;

    return (
      <div>
        <FederationOrgBrowser
          organizations={organizations}
          handleAddOrg={this.handleAddOrg}
          handleRemoveOrg={this.handleRemoveOrg}
          handleShowOrg={this.handleShowOrg}
          mode={mode}
        />
        {selectedOrg ? (
          <FederationDashboard db={db} mode={mode} organization={selectedOrg} />
        ) : (
          <p>No organization selected</p>
        )}
        <SetupOrgModal show={showSetupOrgModal} onHide={this.closeSetupOrgModal} db={db} mode={mode} />
      </div>
    );
  }
}
export default Federation;
